import XCTest
import Combine
import UIKit
@testable import FridgeChef

@MainActor
final class HomeVMTests: XCTestCase {

    private var client: StubOpenAIClient!
    private var store: StubRecipeStore!
    private var vm: HomeVM!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        client = StubOpenAIClient()
        store = StubRecipeStore()
        vm = HomeVM(client: client, store: store)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        vm = nil
        store = nil
        client = nil
        super.tearDown()
    }

    // MARK: - chips

    func test_addChip_appendsTrimmedLowercased() {
        vm.addChip("  Tomato  ")
        XCTAssertEqual(vm.chips, ["tomato"])
    }

    func test_addChip_ignoresDuplicates() {
        vm.addChip("tomato")
        vm.addChip("TOMATO")
        vm.addChip("  tomato ")
        XCTAssertEqual(vm.chips, ["tomato"])
    }

    func test_addChip_ignoresEmptyOrWhitespace() {
        vm.addChip("")
        vm.addChip("   ")
        XCTAssertEqual(vm.chips, [])
    }

    func test_removeChip_removesByName() {
        vm.addChip("a"); vm.addChip("b"); vm.addChip("c")
        vm.removeChip("b")
        XCTAssertEqual(vm.chips, ["a", "c"])
    }

    func test_canGenerate_falseWhenEmpty_trueOtherwise() {
        XCTAssertFalse(vm.canGenerate)
        vm.addChip("x")
        XCTAssertTrue(vm.canGenerate)
    }

    // MARK: - generate (text)

    func test_generate_textHappyPath_setsLoadingThenLoaded_andSaves() async {
        client.textResult = .success(sampleRecipes(3))
        vm.addChip("tomato"); vm.addChip("basil")

        let exp = expectation(description: "loaded")
        var seen: [HomeVM.State] = []
        vm.$state.dropFirst().sink {
            seen.append($0)
            if case .loaded = $0 { exp.fulfill() }
        }.store(in: &cancellables)

        vm.generate()
        await fulfillment(of: [exp], timeout: 1.0)

        XCTAssertEqual(seen.first, .loading)
        if case .loaded(let batch) = seen.last {
            XCTAssertEqual(batch.recipes.count, 3)
            XCTAssertEqual(batch.inputIngredients, ["tomato", "basil"])
            XCTAssertNil(batch.inputImageThumbnailJPEG)
        } else {
            XCTFail("expected .loaded last, got \(String(describing: seen.last))")
        }
        XCTAssertEqual(store.batches.count, 1)
        XCTAssertEqual(client.lastIngredients, ["tomato", "basil"])
    }

    func test_generate_errorMapsToErrorState() async {
        client.textResult = .failure(OpenAIError.unauthorized)
        vm.addChip("x")

        let exp = expectation(description: "error")
        vm.$state.dropFirst().sink {
            if case .error = $0 { exp.fulfill() }
        }.store(in: &cancellables)

        vm.generate()
        await fulfillment(of: [exp], timeout: 1.0)

        if case .error(let msg) = vm.state {
            XCTAssertTrue(msg.contains("API key invalid"))
        } else { XCTFail("expected .error, got \(vm.state)") }
        XCTAssertEqual(store.batches.count, 0)
    }

    func test_generate_doesNothingWhenNoChips() {
        vm.generate()
        XCTAssertEqual(vm.state, .idle)
        XCTAssertNil(client.lastIngredients)
    }

    // MARK: - generate (image)

    func test_generate_imageHappyPath_attachesThumbnail() async {
        client.imageResult = .success(sampleRecipes(3))
        let img = makeRedSquare(size: 200)

        let exp = expectation(description: "loaded")
        vm.$state.dropFirst().sink {
            if case .loaded = $0 { exp.fulfill() }
        }.store(in: &cancellables)

        vm.generate(image: img)
        await fulfillment(of: [exp], timeout: 2.0)

        if case .loaded(let batch) = vm.state {
            XCTAssertNotNil(batch.inputImageThumbnailJPEG)
            XCTAssertGreaterThan(batch.inputImageThumbnailJPEG?.count ?? 0, 100)
        } else { XCTFail() }
        XCTAssertNotNil(client.lastImageJPEG)
    }

    // MARK: - helpers

    private func sampleRecipes(_ n: Int) -> [Recipe] {
        (0..<n).map { i in
            Recipe(id: UUID(), title: "T\(i)", description: "d", ingredients: [], steps: [], estimatedTime: "5 min")
        }
    }

    private func makeRedSquare(size: CGFloat) -> UIImage {
        let r = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        let renderer = UIGraphicsImageRenderer(size: r.size)
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(r)
        }
    }
}
