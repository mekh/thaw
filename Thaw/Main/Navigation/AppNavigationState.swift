//
//  AppNavigationState.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Combine

/// The model for app-wide navigation.
@MainActor
final class AppNavigationState: ObservableObject {
    nonisolated enum SettingsDisclosure: Hashable {
        case advancedLayoutControls
        case emptyMenuBarArea
    }

    @Published var isAppFrontmost = false
    @Published var isSettingsPresented = false
    @Published var isIceBarPresented = false
    @Published var isSearchPresented = false
    @Published var settingsNavigationIdentifier: SettingsNavigationIdentifier = .general
    @Published var requestedSettingsDisclosure: SettingsDisclosure?

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Reopen settings on the pane the user last used. A pane that Simple
        // Mode hides would restore an unselectable sidebar row, so fall back
        // to the default (General) in that case.
        if let rawValue = Defaults.string(forKey: .lastSettingsPane),
           let pane = SettingsNavigationIdentifier(rawValue: rawValue),
           !Defaults.bool(forKey: .simpleMode) || pane.isVisibleInSimpleMode {
            settingsNavigationIdentifier = pane
        }
        $settingsNavigationIdentifier
            .dropFirst()
            .sink { pane in
                Defaults.set(pane.rawValue, forKey: .lastSettingsPane)
            }
            .store(in: &cancellables)
    }
}
