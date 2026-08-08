//
//  MenuBarSpacerManager.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Cocoa
import Combine
import MenuBarModel

// MARK: - MenuBarSpacer

/// One user-created spacer item.
nonisolated struct MenuBarSpacer: Codable, Identifiable, Equatable {
    /// The narrowest useful spacer; anything below reads as a normal gap.
    static let minWidth: CGFloat = 8
    /// Wide enough to push items past a notch without being a footgun.
    static let maxWidth: CGFloat = 300
    /// A visible, obviously-intentional default gap.
    static let defaultWidth: CGFloat = 40

    let id: UUID
    var width: CGFloat
    /// Optional fill; `nil` renders the spacer as a fully transparent gap.
    var color: IceColor?

    init(id: UUID = UUID(), width: CGFloat = Self.defaultWidth, color: IceColor? = nil) {
        self.id = id
        self.width = width.clamped(to: Self.minWidth ... Self.maxWidth)
        self.color = color
    }
}

// MARK: - MenuBarSpacerManager

/// Owns the user's spacer items: synthetic status items whose only job is
/// occupying width between real items. Users position them like any other
/// item (⌘-drag in the menu bar or via the layout editor).
///
/// The status-item mechanics — the `Thaw.ControlItem.` autosave prefix that
/// keeps spacers outside Thaw's own concealment, the two `NSStatusItem
/// Visible*` defaults macOS 27 consults, and the requirement that the button
/// carry a real image to be composited — are the ones `OverflowSpacer`
/// validated.
@MainActor
final class MenuBarSpacerManager: ObservableObject {
    /// Deliberately NOT under `Thaw.ControlItem.` — that prefix marks Thaw's
    /// immovable anchors (never drag sources, excluded from section
    /// assignment, special-cased right-click). Spacers are ordinary items.
    nonisolated static let autosavePrefix = "Thaw.Spacer."

    /// The prefix spacers briefly shipped under; migrated away because it
    /// made them immovable control items.
    private nonisolated static let legacyAutosavePrefix = "Thaw.ControlItem.Spacer."

    /// Whether a cached item tag belongs to one of Thaw's spacers, so
    /// capture consumers (layout editor, search) can identify them.
    nonisolated static func isSpacerTag(_ tag: MenuBarItemTag) -> Bool {
        tag.title.hasPrefix(autosavePrefix)
    }

    /// Whether one of the live spacer status items owns this window.
    ///
    /// Identification by window is the reliable path right after creation:
    /// the button window (and thus the cached tag's title) can lag behind,
    /// leaving the tag a generic "Item-0" until the title assertion lands.
    func ownsWindowID(_ windowID: CGWindowID) -> Bool {
        statusItems.values.contains { item in
            guard let windowNumber = item.button?.window?.windowNumber, windowNumber > 0 else {
                return false
            }
            return CGWindowID(windowNumber) == windowID
        }
    }

    private let diagLog = DiagLog(category: "MenuBarSpacerManager")
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// The user's spacers, in creation order. Persisted; the on-screen order
    /// is whatever the user drags them to, owned by AppKit's autosave.
    @Published private(set) var spacers: [MenuBarSpacer] = []

    private var statusItems: [UUID: NSStatusItem] = [:]
    /// The spacer state each live status item was last configured with.
    private var applied: [UUID: MenuBarSpacer] = [:]
    private var cancellables = Set<AnyCancellable>()

    func performSetup(with _: AppState) {
        loadInitialState()
        reconcileStatusItems()
        $spacers
            .dropFirst()
            .encode(encoder: encoder)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.diagLog.error("Error encoding spacers: \(error)")
                }
            } receiveValue: { data in
                Defaults.set(data, forKey: .menuBarSpacers)
            }
            .store(in: &cancellables)
    }

    private func loadInitialState() {
        guard let data = Defaults.data(forKey: .menuBarSpacers) else {
            return
        }
        do {
            spacers = try decoder.decode([MenuBarSpacer].self, from: data)
        } catch {
            diagLog.error("Error decoding spacers: \(error)")
        }
    }

    // MARK: Mutations

    func addSpacer() {
        spacers.append(MenuBarSpacer())
        reconcileStatusItems()
    }

    func removeSpacer(id: UUID) {
        spacers.removeAll { $0.id == id }
        reconcileStatusItems()
    }

    func setWidth(_ width: CGFloat, for id: UUID) {
        guard let index = spacers.firstIndex(where: { $0.id == id }) else {
            return
        }
        spacers[index].width = width.clamped(to: MenuBarSpacer.minWidth ... MenuBarSpacer.maxWidth)
        reconcileStatusItems()
    }

    func setColor(_ cgColor: CGColor?, for id: UUID) {
        guard let index = spacers.firstIndex(where: { $0.id == id }) else {
            return
        }
        spacers[index].color = cgColor.map { IceColor(cgColor: $0) }
        reconcileStatusItems()
    }

    // MARK: Status Items

    private static func autosaveName(for id: UUID) -> String {
        autosavePrefix + id.uuidString
    }

    /// A slab at the requested width — transparent when no color is set.
    /// The button must carry a real image either way; macOS 27 composites a
    /// contentless button as nothing.
    private static func spacerImage(width: CGFloat, color: IceColor?) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: 16), flipped: false) { rect in
            if let color, let fill = NSColor(cgColor: color.cgColor) {
                fill.setFill()
                NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private func assertWindowTitle(for id: UUID, attempt: Int) {
        guard let item = statusItems[id] else {
            return
        }
        let name = Self.autosaveName(for: id)
        if let window = item.button?.window {
            window.title = name
        } else if attempt < 20 {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                self?.assertWindowTitle(for: id, attempt: attempt + 1)
            }
        } else {
            diagLog.warning("Spacer \(id) never produced a button window; title not set")
        }
    }

    private func reconcileStatusItems() {
        // Drop items whose spacer is gone, and clean up the autosave litter
        // so removed spacers can't influence future layout.
        let wanted = Set(spacers.map(\.id))
        for (id, item) in statusItems where !wanted.contains(id) {
            NSStatusBar.system.removeStatusItem(item)
            statusItems[id] = nil
            applied[id] = nil
            let name = Self.autosaveName(for: id)
            ControlItemDefaults[.preferredPosition, name] = nil
            UserDefaults.standard.removeObject(forKey: "NSStatusItem Visible \(name)")
            UserDefaults.standard.removeObject(forKey: "NSStatusItem VisibleCC \(name)")
            diagLog.info("Removed spacer \(id)")
        }

        for spacer in spacers {
            if let item = statusItems[spacer.id] {
                if applied[spacer.id] != spacer {
                    item.length = spacer.width
                    item.button?.image = Self.spacerImage(width: spacer.width, color: spacer.color)
                    applied[spacer.id] = spacer
                }
                continue
            }

            let name = Self.autosaveName(for: spacer.id)
            // Migrate any state saved under the legacy control-item prefix.
            let legacyName = Self.legacyAutosavePrefix + spacer.id.uuidString
            if ControlItemDefaults[.preferredPosition, name] == nil,
               let legacyPosition: CGFloat = ControlItemDefaults[.preferredPosition, legacyName] {
                ControlItemDefaults[.preferredPosition, name] = legacyPosition
                ControlItemDefaults[.preferredPosition, legacyName] = nil
            }
            UserDefaults.standard.removeObject(forKey: "NSStatusItem Visible \(legacyName)")
            UserDefaults.standard.removeObject(forKey: "NSStatusItem VisibleCC \(legacyName)")

            // Seed new spacers just right of the Thaw icon — inside the
            // visible region, so a freshly added spacer is never born into a
            // concealed slot — and assert both visibility switches before
            // creation; macOS 27 consults the CC channel per item.
            if ControlItemDefaults[.preferredPosition, name] == nil {
                let thawIconPosition: CGFloat =
                    ControlItemDefaults[.preferredPosition, ControlItem.Identifier.visible.rawValue] ?? 0
                ControlItemDefaults[.preferredPosition, name] = max(thawIconPosition - 1, 0)
            }
            UserDefaults.standard.set(true, forKey: "NSStatusItem Visible \(name)")
            UserDefaults.standard.set(true, forKey: "NSStatusItem VisibleCC \(name)")

            let item = NSStatusBar.system.statusItem(withLength: spacer.width)
            item.autosaveName = name
            item.button?.image = Self.spacerImage(width: spacer.width, color: spacer.color)
            item.button?.imageScaling = .scaleNone
            item.button?.toolTip = String(localized: "\(Constants.displayName) spacer")
            // macOS 27 enumerates items through the AX tree, and identity
            // comes from the accessibility identifier — the window title only
            // covers the macOS 26 CGS path. Without this, the spacer's tag is
            // a generic "Item-0" and preferred-position moves can't verify.
            if #available(macOS 27, *) {
                item.button?.setAccessibilityIdentifier(name)
            }
            statusItems[spacer.id] = item
            // The button window often doesn't exist yet at creation time;
            // without the title, the item cache tags the spacer as a generic
            // "Item-0" and can't identify it. Retry until the window is up.
            assertWindowTitle(for: spacer.id, attempt: 0)
            applied[spacer.id] = spacer
            diagLog.info("Created spacer \(spacer.id), width=\(Int(spacer.width))pt")
        }
    }
}
