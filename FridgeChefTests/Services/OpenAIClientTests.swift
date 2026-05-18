import XCTest
@testable import FridgeChef

final class OpenAIClientTests: XCTestCase {

    override func setUp() { super.setUp(); StubURLProtocol.reset() }
    override func tearDown() { StubURLProtocol.reset(); super.tearDown() }

    private func makeClient() -> OpenAIClient {
        OpenAIClient(apiKey: "sk-test-12345", session: StubURLProtocol.session())
    }

    // MARK: - request shape

    func test_textRequest_targetsChatCompletionsEndpoint() async throws {
        StubURLProtocol.responder = { _ in (Self.okResponse, Self.threeRecipesJSON) }
        _ = try await makeClient().suggestRecipes(ingredients: ["tomato"])
        let req = StubURLProtocol.lastRequest!
        XCTAssertEqual(req.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(req.httpMethod, "POST")
    }

    func test_textRequest_includesBearerAuthHeader() async throws {
        StubURLProtocol.responder = { _ in (Self.okResponse, Self.threeRecipesJSON) }
        _ = try await makeClient().suggestRecipes(ingredients: ["tomato"])
        let auth = StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(auth, "Bearer sk-test-12345")
    }

    func test_textRequest_includesJSONContentType() async throws {
        StubURLProtocol.responder = { _ in (Self.okResponse, Self.threeRecipesJSON) }
        _ = try await makeClient().suggestRecipes(ingredients: ["tomato"])
        let ct = StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type")
        XCTAssertEqual(ct, "application/json")
    }

    func test_textRequest_bodyHasModelMessagesAndResponseFormat() async throws {
        StubURLProtocol.responder = { _ in (Self.okResponse, Self.threeRecipesJSON) }
        _ = try await makeClient().suggestRecipes(ingredients: ["tomato", "basil"])
        let body = try XCTUnwrap(StubURLProtocol.lastRequest?.httpBodyStream.flatMap(Data.from(stream:)))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "gpt-4o")
        XCTAssertNotNil(json["messages"])
        let format = json["response_format"] as? [String: Any]
        XCTAssertEqual(format?["type"] as? String, "json_schema")
        let messages = json["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.count, 2)
        XCTAssertEqual(messages?[0]["role"] as? String, "system")
        XCTAssertEqual(messages?[1]["role"] as? String, "user")
        let userContent = messages?[1]["content"] as? String ?? ""
        XCTAssertTrue(userContent.contains("tomato"))
        XCTAssertTrue(userContent.contains("basil"))
    }

    // MARK: - response decoding

    func test_textResponse_decodesThreeRecipes() async throws {
        StubURLProtocol.responder = { _ in (Self.okResponse, Self.threeRecipesJSON) }
        let recipes = try await makeClient().suggestRecipes(ingredients: ["tomato"])
        XCTAssertEqual(recipes.count, 3)
        XCTAssertEqual(recipes[0].title, "Pasta")
        XCTAssertEqual(recipes[1].title, "Salad")
        XCTAssertEqual(recipes[2].title, "Bruschetta")
        XCTAssertEqual(recipes[0].estimatedTime, "30 min")
        XCTAssertEqual(recipes[0].ingredients, ["tomato"])
        XCTAssertEqual(recipes[1].steps, ["toss"])
        XCTAssertEqual(Set(recipes.map(\.id)).count, 3)
    }

    // MARK: - error mapping

    func test_401_throwsUnauthorized() async {
        StubURLProtocol.responder = { _ in (Self.response(401), Data()) }
        await XCTAssertThrowsErrorAsync(try await self.makeClient().suggestRecipes(ingredients: ["x"])) { err in
            XCTAssertEqual(err as? OpenAIError, .unauthorized)
        }
    }

    func test_429_throwsRateLimited() async {
        StubURLProtocol.responder = { _ in (Self.response(429), Data()) }
        await XCTAssertThrowsErrorAsync(try await self.makeClient().suggestRecipes(ingredients: ["x"])) { err in
            XCTAssertEqual(err as? OpenAIError, .rateLimited)
        }
    }

    func test_500_throwsServer() async {
        StubURLProtocol.responder = { _ in (Self.response(500), Data()) }
        await XCTAssertThrowsErrorAsync(try await self.makeClient().suggestRecipes(ingredients: ["x"])) { err in
            XCTAssertEqual(err as? OpenAIError, .server(500))
        }
    }

    func test_malformedEnvelope_throwsInvalidResponse() async {
        StubURLProtocol.responder = { _ in (Self.okResponse, "not json".data(using: .utf8)!) }
        await XCTAssertThrowsErrorAsync(try await self.makeClient().suggestRecipes(ingredients: ["x"])) { err in
            XCTAssertEqual(err as? OpenAIError, .invalidResponse)
        }
    }

    func test_malformedRecipeJSON_throwsDecoding() async {
        let badContent = """
        { "choices": [{ "message": { "content": "{\\"recipes\\":[{\\"bogus\\":true}]}" } }] }
        """.data(using: .utf8)!
        StubURLProtocol.responder = { _ in (Self.okResponse, badContent) }
        await XCTAssertThrowsErrorAsync(try await self.makeClient().suggestRecipes(ingredients: ["x"])) { err in
            if case .decoding = err as? OpenAIError {} else { XCTFail("expected .decoding, got \(err)") }
        }
    }

    // MARK: - image variant

    func test_imageRequest_bodyHasImageUrlContent() async throws {
        StubURLProtocol.responder = { _ in (Self.okResponse, Self.threeRecipesJSON) }
        let fakeJPEG = Data([0xFF, 0xD8, 0xFF, 0xD9])
        _ = try await makeClient().suggestRecipes(imageJPEG: fakeJPEG)
        let body = try XCTUnwrap(StubURLProtocol.lastRequest?.httpBodyStream.flatMap(Data.from(stream:)))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        let userContent = try XCTUnwrap(messages[1]["content"] as? [[String: Any]])
        XCTAssertEqual(userContent.count, 2)
        XCTAssertEqual(userContent[0]["type"] as? String, "text")
        XCTAssertEqual(userContent[1]["type"] as? String, "image_url")
        let imageURL = userContent[1]["image_url"] as? [String: Any]
        let urlString = imageURL?["url"] as? String ?? ""
        XCTAssertTrue(urlString.hasPrefix("data:image/jpeg;base64,"))
        XCTAssertTrue(urlString.contains(fakeJPEG.base64EncodedString()))
    }

    // MARK: - fixtures

    static let okResponse = HTTPURLResponse(
        url: URL(string: "https://api.openai.com/v1/chat/completions")!,
        statusCode: 200, httpVersion: nil, headerFields: nil)!

    static func response(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.openai.com/v1/chat/completions")!,
                        statusCode: code, httpVersion: nil, headerFields: nil)!
    }

    static let threeRecipesJSON: Data = """
    {
      "choices": [{
        "message": {
          "content": "{\\"recipes\\":[{\\"title\\":\\"Pasta\\",\\"description\\":\\"d1\\",\\"ingredients\\":[\\"tomato\\"],\\"steps\\":[\\"boil\\"],\\"estimatedTime\\":\\"30 min\\"},{\\"title\\":\\"Salad\\",\\"description\\":\\"d2\\",\\"ingredients\\":[\\"basil\\"],\\"steps\\":[\\"toss\\"],\\"estimatedTime\\":\\"5 min\\"},{\\"title\\":\\"Bruschetta\\",\\"description\\":\\"d3\\",\\"ingredients\\":[\\"bread\\"],\\"steps\\":[\\"toast\\"],\\"estimatedTime\\":\\"10 min\\"}]}"
        }
      }]
    }
    """.data(using: .utf8)!
}

extension Data {
    static func from(stream: InputStream) -> Data {
        stream.open(); defer { stream.close() }
        var data = Data()
        let bufSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufSize)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: bufSize)
            if n > 0 { data.append(buffer, count: n) } else { break }
        }
        return data
    }
}

func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #file,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("expected error, got success", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
