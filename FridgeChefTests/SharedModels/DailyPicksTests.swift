// FridgeChefTests/SharedModels/DailyPicksTests.swift
import XCTest
@testable import FridgeChef

final class DailyPicksTests: XCTestCase {

    func test_roundTripsThroughJSON() throws {
        let original = DailyPicks(
            breakfast: "Avocado toast",
            lunch: "Pesto pasta",
            dinner: "Miso salmon",
            savedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DailyPicks.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_titleForMealReturnsCorrectValue() {
        let picks = DailyPicks(
            breakfast: "Oats",
            lunch: "Salad",
            dinner: "Curry",
            savedAt: Date()
        )
        XCTAssertEqual(picks.title(for: .breakfast), "Oats")
        XCTAssertEqual(picks.title(for: .lunch), "Salad")
        XCTAssertEqual(picks.title(for: .dinner), "Curry")
    }
}
