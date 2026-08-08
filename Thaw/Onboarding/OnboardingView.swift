//
//  OnboardingView.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// Shared window dimensions for onboarding and permissions flows.
enum ThawOnboardingWindowMetrics {
    static let width: CGFloat = 608
    static let height: CGFloat = 480
}

/// Full first-launch experience: feature tour, then separate permissions
/// screen, then optional completion confirmation.
struct ThawOnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Step {
        case tour
        case modeChoice
        case permissions
        case done
    }

    @State private var step = Step.tour

    private let showsCompletionScreen: Bool
    private let onSelectSimpleMode: (Bool) -> Void
    private let onComplete: () -> Void

    /// Creates the reusable onboarding flow.
    /// - Parameters:
    ///   - showsCompletionScreen: When `true`, the package shows a final
    ///     confirmation screen after permissions. Set this to `false` when the
    ///     host app dismisses onboarding in `onComplete`.
    ///   - onSelectSimpleMode: Called with the user's Simple-or-Full choice
    ///     after the tour. The flow stays decoupled from the settings models,
    ///     so applying the choice is the host's job.
    ///   - onComplete: Called once the user finishes the permissions step.
    init(
        showsCompletionScreen: Bool = true,
        onSelectSimpleMode: @escaping (Bool) -> Void = { _ in },
        onComplete: @escaping () -> Void
    ) {
        self.showsCompletionScreen = showsCompletionScreen
        self.onSelectSimpleMode = onSelectSimpleMode
        self.onComplete = onComplete
    }

    var body: some View {
        Group {
            switch step {
            case .tour:
                ThawOnboardingTour(onFinish: { step = .modeChoice })
                    .transition(.opacity)
            case .modeChoice:
                ThawModeChoiceView { simpleMode in
                    onSelectSimpleMode(simpleMode)
                    step = .permissions
                }
                .transition(.opacity)
            case .permissions:
                ThawPermissionsView(onContinue: complete)
                    .transition(.opacity)
            case .done:
                ThawOnboardingDoneView()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: step)
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }

    private func complete() {
        if showsCompletionScreen {
            step = .done
        }

        onComplete()
    }
}

/// Lets a new user choose between Simple Mode and the full settings surface.
///
/// The copy mirrors the Simple Mode contract: the choice only trims the
/// settings window — every feature keeps working either way — and it can be
/// revisited in General settings at any time.
private struct ThawModeChoiceView: View {
    var onChoose: (_ simpleMode: Bool) -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            Text("Choose Your Starting Point")
                .font(.title.bold())

            Text("Pick how much of Thaw you want to see in settings. Every feature keeps working either way.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            HStack(spacing: 16) {
                choiceCard(
                    title: String(localized: "Simple"),
                    symbol: "sparkles",
                    description: String(localized: "Just the essentials: hiding, layout, and appearance."),
                    simpleMode: true
                )
                choiceCard(
                    title: String(localized: "Full"),
                    symbol: "slider.horizontal.3",
                    description: String(localized: "Every option, including layout, profiles, and automation."),
                    simpleMode: false
                )
            }
            .padding(.top, 8)

            Text("You can change this anytime in General settings.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground())
    }

    private func choiceCard(
        title: String,
        symbol: String,
        description: String,
        simpleMode: Bool
    ) -> some View {
        Button {
            onChoose(simpleMode)
        } label: {
            VStack(spacing: 10) {
                GlassIconBubble(symbol: symbol, size: 44)
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 230, height: 160)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(description))
    }
}

private struct ThawOnboardingDoneView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.green)

            Text("You're All Set")
                .font(.title.bold())

            Text("Thaw is ready to manage your menu bar.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground())
    }
}
