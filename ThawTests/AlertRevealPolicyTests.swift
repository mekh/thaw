//
//  AlertRevealPolicyTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@testable import Thaw
import XCTest

final class AlertRevealPolicyTests: XCTestCase {
    func testFirstRevealIsAllowedAndRecorded() {
        var policy = AlertRevealPolicy(cooldown: 45)
        let now = Date()
        XCTAssertTrue(policy.shouldReveal("com.example.app:Item", now: now))
        XCTAssertEqual(policy.lastRevealDates["com.example.app:Item"], now)
    }

    func testRevealWithinCooldownIsSuppressed() {
        var policy = AlertRevealPolicy(cooldown: 45)
        let now = Date()
        XCTAssertTrue(policy.shouldReveal("id", now: now))
        XCTAssertFalse(policy.shouldReveal("id", now: now.addingTimeInterval(44)))
        // A suppressed attempt must not extend the cooldown window.
        XCTAssertEqual(policy.lastRevealDates["id"], now)
    }

    func testRevealAfterCooldownIsAllowed() {
        var policy = AlertRevealPolicy(cooldown: 45)
        let now = Date()
        XCTAssertTrue(policy.shouldReveal("id", now: now))
        XCTAssertTrue(policy.shouldReveal("id", now: now.addingTimeInterval(45)))
    }

    func testCooldownIsPerItem() {
        var policy = AlertRevealPolicy(cooldown: 45)
        let now = Date()
        XCTAssertTrue(policy.shouldReveal("a", now: now))
        XCTAssertTrue(policy.shouldReveal("b", now: now))
    }
}
