import XCTest
@testable import FridgeChef

final class APIKeyProviderTests: XCTestCase {

    func test_get_returns_key_when_present_in_bundle() throws {
        let stub = StubBundle(info: ["OPENAI_API_KEY": "sk-test-12345"])
        let key = try APIKeyProvider.get(from: stub)
        XCTAssertEqual(key, "sk-test-12345")
    }

    func test_get_throws_missingAPIKey_when_absent() {
        let stub = StubBundle(info: [:])
        XCTAssertThrowsError(try APIKeyProvider.get(from: stub)) { err in
            XCTAssertEqual(err as? OpenAIError, .missingAPIKey)
        }
    }

    func test_get_throws_missingAPIKey_when_empty_string() {
        let stub = StubBundle(info: ["OPENAI_API_KEY": ""])
        XCTAssertThrowsError(try APIKeyProvider.get(from: stub)) { err in
            XCTAssertEqual(err as? OpenAIError, .missingAPIKey)
        }
    }
}

private final class StubBundle: InfoDictionaryProvider {
    let info: [String: Any]
    init(info: [String: Any]) { self.info = info }
    func object(forInfoDictionaryKey key: String) -> Any? { info[key] }
}
