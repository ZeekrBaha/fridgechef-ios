import XCTest
import Combine
@testable import FridgeChef

@MainActor
final class RecipesVMTests: XCTestCase {

    private var store: StubRecipeStore!
    private var vm: RecipesVM!

    override func setUp() {
        super.setUp()
        store = StubRecipeStore()
        vm = RecipesVM(store: store, calendar: .current, now: { Date(timeIntervalSince1970: 1747584840) })
    }

    func test_load_emptyStore_emitsEmptyGroups() async {
        await vm.load()
        XCTAssertEqual(vm.groups, [])
    }

    func test_load_groupsBatchesByRelativeDate() async {
        let now = Date(timeIntervalSince1970: 1747584840)
        let today = now.addingTimeInterval(-3600)
        let yesterday = now.addingTimeInterval(-90_000)
        let lastWeek = now.addingTimeInterval(-3 * 86_400)
        store.batches = [
            makeBatch(date: today),
            makeBatch(date: yesterday),
            makeBatch(date: lastWeek),
        ]
        await vm.load()
        let titles = vm.groups.map(\.title)
        XCTAssertEqual(titles.first, "TODAY")
        XCTAssertTrue(titles.contains("YESTERDAY"))
        // "lastWeek" (3 days ago) is within the rolling 7-day window → THIS WEEK
        XCTAssertTrue(titles.contains("THIS WEEK"))
    }

    func test_reload_onNotification() async {
        store.batches = [makeBatch(date: Date(timeIntervalSince1970: 1747584000))]
        await vm.load()
        XCTAssertEqual(vm.groups.flatMap(\.items).count, 1)

        store.batches = []
        NotificationCenter.default.post(name: .recipesDidChange, object: nil)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(vm.groups, [])
    }

    private func makeBatch(date: Date) -> RecipeBatch {
        RecipeBatch(id: UUID(), createdAt: date,
                    inputIngredients: ["x"],
                    inputImageThumbnailJPEG: nil,
                    recipes: [],
                    source: .ai)
    }
}
