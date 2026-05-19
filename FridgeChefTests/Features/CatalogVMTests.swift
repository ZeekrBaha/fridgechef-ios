import XCTest
import Combine
@testable import FridgeChef

@MainActor
final class CatalogVMTests: XCTestCase {

    var client: StubOpenAIClient!
    var store: StubRecipeStore!
    var dailyPicks: StubDailyPicksService!
    var vm: CatalogVM!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        client = StubOpenAIClient()
        store = StubRecipeStore()
        dailyPicks = StubDailyPicksService()
        vm = CatalogVM(client: client, store: store, dailyPicks: dailyPicks)
        cancellables = []
    }

    override func tearDown() async throws {
        cancellables = nil
        try await super.tearDown()
    }

    func test_generateForDish_savesBatchAndTransitionsToLoaded() async throws {
        let recipes = (0..<3).map { i in
            Recipe(id: UUID(), title: "T\(i)", description: "d",
                   ingredients: ["a"], steps: ["s"], estimatedTime: "10 min")
        }
        client.dishResult = .success(recipes)

        var states: [CatalogVM.State] = []
        vm.$state.sink { states.append($0) }.store(in: &cancellables)

        vm.generateForDish("ramen")

        await Task.yield()
        for _ in 0..<10 where !states.contains(where: { if case .loaded = $0 { return true } else { return false } }) {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(client.lastDishName, "ramen")
        XCTAssertEqual(store.batches.count, 1)
        if case .loaded(let batch) = vm.state {
            XCTAssertEqual(batch.recipes.count, 3)
        } else {
            XCTFail("Expected .loaded, got \(vm.state)")
        }
    }

    func test_generateForMeal_callsClientWithMeal_andNilStyle() async throws {
        let recipes = (0..<3).map { _ in
            Recipe(id: UUID(), title: "x", description: "d",
                   ingredients: ["a"], steps: ["s"], estimatedTime: "10 min")
        }
        client.mealResult = .success(recipes)

        vm.generateForMeal(.lunch)

        for _ in 0..<10 where vm.state == .loading || vm.state == .idle {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(client.lastMeal, .lunch)
        XCTAssertNil(client.lastStyle)
        if case .loaded = vm.state {} else {
            XCTFail("Expected .loaded, got \(vm.state)")
        }
    }

    func test_generateRandom_callsClientWithSomeMealAndSomeStyle() async throws {
        let recipes = (0..<3).map { _ in
            Recipe(id: UUID(), title: "x", description: "d",
                   ingredients: ["a"], steps: ["s"], estimatedTime: "10 min")
        }
        client.mealResult = .success(recipes)

        vm.generateRandom()

        for _ in 0..<10 where vm.state == .loading || vm.state == .idle {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertNotNil(client.lastMeal, "generateRandom must pick a meal type")
        XCTAssertNotNil(client.lastStyle, "generateRandom must pick a style")
    }

    func test_dailyPicks_reactsToServicePublisher() async throws {
        XCTAssertNil(vm.dailyPicks)

        let exp = expectation(description: "vm receives picks")
        vm.$dailyPicks
            .dropFirst()
            .sink { picks in
                if picks?.breakfast == "Oats" { exp.fulfill() }
            }
            .store(in: &cancellables)

        let fresh = DailyPicks(breakfast: "Oats", lunch: "Salad", dinner: "Curry", savedAt: Date())
        dailyPicks.emit(fresh)

        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(vm.dailyPicks?.breakfast, "Oats")
    }

    func test_generateForDish_failure_transitionsToError() async throws {
        struct Boom: LocalizedError { var errorDescription: String? { "boom" } }
        client.dishResult = .failure(Boom())

        vm.generateForDish("ramen")

        for _ in 0..<10 where vm.state == .loading || vm.state == .idle {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        if case .error(let msg) = vm.state {
            XCTAssertEqual(msg, "boom")
        } else {
            XCTFail("Expected .error, got \(vm.state)")
        }
    }

    func test_refreshDailyPicksIfStale_callsService() async throws {
        XCTAssertEqual(dailyPicks.refreshCallCount, 0)

        vm.refreshDailyPicksIfStale()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(dailyPicks.refreshCallCount, 1)
    }
}
