//
//  MenuBarSpacerTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@testable import Thaw
import XCTest

final class MenuBarSpacerTests: XCTestCase {
    func testInitClampsWidth() {
        XCTAssertEqual(MenuBarSpacer(width: 1).width, MenuBarSpacer.minWidth)
        XCTAssertEqual(MenuBarSpacer(width: 10_000).width, MenuBarSpacer.maxWidth)
        XCTAssertEqual(MenuBarSpacer(width: 40).width, 40)
    }

    func testDefaultWidthIsWithinBounds() {
        let spacer = MenuBarSpacer()
        XCTAssertEqual(spacer.width, MenuBarSpacer.defaultWidth)
        XCTAssertTrue((MenuBarSpacer.minWidth ... MenuBarSpacer.maxWidth).contains(spacer.width))
    }

    func testCodableRoundTrip() throws {
        let spacers = [MenuBarSpacer(width: 24), MenuBarSpacer(width: 120)]
        let data = try JSONEncoder().encode(spacers)
        let decoded = try JSONDecoder().decode([MenuBarSpacer].self, from: data)
        XCTAssertEqual(decoded, spacers)
    }
}
