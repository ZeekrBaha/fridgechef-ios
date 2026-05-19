import XCTest
import Combine
@testable import FridgeChef

@MainActor
final class DailyPicksServiceTests: XCTestCase {

    var defaults: UserDefaults!
    var stubClient: StubOpenAIClient!
    var service: LiveDailyPicksService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: "DailyPicksServiceTests")!
        defaults.removePersistentDomain(forName: "DailyPicksServiceTests")
        stubClient = StubOpenAIClient()
        service = LiveDailyPicksService(client: stubClient, defaults: defaults)
        cancellables = []
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: "DailyPicksServiceTests")
        cancellables = nil
        try await super.tearDown()
    }

    func test_firstLaunch_fetchesAndCaches() async {
        let picks = DailyPicks(
            breakfast: "Oats", lunch: "Salad", dinner: "Curry",
            savedAt: Date()
        )
        stubClient.dailyPicksResult = .success(picks)

        await service.refreshIfStale()

        XCTAssertEqual(service.current?.breakfast, "Oats")
        XCTAssertEqual(stubClient.dailyPicksCallCount, 1)
    }

    func test_freshCache_skipsFetch() async {
        let todayPicks = DailyPicks(
            breakfast: "Cached", lunch: nil, dinner: nil,
            savedAt: Date()
        )
        let encoded = try! JSONEncoder().encode(todayPicks)
        defaults.set(encoded, forKey: "DailyPicksService.cache")

        service = LiveDailyPicksService(client: stubClient, defaults: defaults)
        stubClient.dailyPicksResult = .success(
            DailyPicks(breakfast: "FRESH", lunch: nil, dinner: nil, savedAt: Date())
        )

        await service.refreshIfStale()

        XCTAssertEqual(service.current?.breakfast, "Cached")
        XCTAssertEqual(stubClient.dailyPicksCallCount, 0)
    }

    func test_staleCache_refetches() async {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let oldPicks = DailyPicks(
            breakfast: "Old", lunch: nil, dinner: nil,
            savedAt: yesterday
        )
        let encoded = try! JSONEncoder().encode(oldPicks)
        defaults.set(encoded, forKey: "DailyPicksService.cache")
        service = LiveDailyPicksService(client: stubClient, defaults: defaults)

        stubClient.dailyPicksResult = .success(
            DailyPicks(breakfast: "Fresh", lunch: "L", dinner: "D", savedAt: Date())
        )

        await service.refreshIfStale()

        XCTAssertEqual(service.current?.breakfast, "Fresh")
        XCTAssertEqual(stubClient.dailyPicksCallCount, 1)
    }

    func test_fetchFailure_keepsStaleValueAndDoesNotThrow() async {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let oldPicks = DailyPicks(
            breakfast: "Survived", lunch: nil, dinner: nil,
            savedAt: yesterday
        )
        let encoded = try! JSONEncoder().encode(oldPicks)
        defaults.set(encoded, forKey: "DailyPicksService.cache")
        service = LiveDailyPicksService(client: stubClient, defaults: defaults)

        struct Boom: Error {}
        stubClient.dailyPicksResult = .failure(Boom())

        await service.refreshIfStale()

        XCTAssertEqual(service.current?.breakfast, "Survived")
    }
}
