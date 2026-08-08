//
//  MenuBarAppearanceSpaceOverrideTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@testable import Thaw
import XCTest

final class MenuBarAppearanceSpaceOverrideTests: XCTestCase {
    func testEffectiveConfigurationPrefersActiveSpaceOverride() {
        let base = MenuBarAppearanceConfigurationV2.defaultConfiguration
        var override = base
        override.isDynamic.toggle()

        let resolved = MenuBarAppearanceManager.effectiveConfiguration(
            base: base,
            overrides: ["42": override],
            activeSpaceID: 42
        )
        XCTAssertEqual(resolved, override)
    }

    func testEffectiveConfigurationFallsBackToBase() {
        let base = MenuBarAppearanceConfigurationV2.defaultConfiguration
        var override = base
        override.isDynamic.toggle()

        XCTAssertEqual(
            MenuBarAppearanceManager.effectiveConfiguration(
                base: base,
                overrides: ["42": override],
                activeSpaceID: 7
            ),
            base
        )
        XCTAssertEqual(
            MenuBarAppearanceManager.effectiveConfiguration(
                base: base,
                overrides: [:],
                activeSpaceID: 42
            ),
            base
        )
    }
}
