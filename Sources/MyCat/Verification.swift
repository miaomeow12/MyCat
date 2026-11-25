import Cocoa

// In-process offline fixture transport. Used only by --generation-test, never the normal app.
private final class ImageFixtureProtocol: URLProtocol {
    static var fixture = Data()
    static var status = 200
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "text/event-stream"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let data = Self.fixture
        for offset in stride(from: 0, to: data.count, by: 4093) {
            client?.urlProtocol(self, didLoad: data.subdata(in: offset..<min(offset + 4093, data.count)))
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@MainActor
func runGenerationChecks(assetURL: URL) async throws {
    let image = try Data(contentsOf: assetURL)
    let key = "TEST_ONLY_NOT_A_REAL_KEY"
    let request = try ImageAPI.request(photo: image, key: key, model: "gpt-image-2.5-flare")
    precondition(request.url?.absoluteString == "https://api.openai.com/v1/images/edits")
    precondition(request.httpMethod == "POST")
    let payload = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
    precondition(payload["stream"] as? Bool == true && payload["partial_images"] as? Int == 2)
    precondition(payload["background"] as? String == "transparent")
    precondition(!String(data: request.httpBody!, encoding: .utf8)!.contains(key), "Key must not enter prompt or request body")
    let photo = (payload["images"] as! [[String: String]])[0]["image_url"]!
    precondition(photo.hasPrefix("data:image/png;base64,"))
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [ImageFixtureProtocol.self] // All requests intercepted; cannot reach network.
    func event(_ type: String) throws -> Data {
        let json = try JSONSerialization.data(withJSONObject: ["type": type, "b64_json": image.base64EncodedString()])
        return Data(("event: \(type)\ndata: " + String(data: json, encoding: .utf8)! + "\n\n").utf8)
    }
    ImageFixtureProtocol.fixture = try event("image_edit.partial_image") + event("image_edit.completed")
    ImageFixtureProtocol.status = 200
    var previews = 0
    let result = try await ImageAPI.generate(photo: image, key: key, model: "gpt-image-2.5-flare", preview: { data in
        await MainActor.run { precondition(data == image); previews += 1 }
    }, configuration: config)
    precondition(result == image && previews == 1, "Stream must deliver real preview and final data across chunk boundaries")
    let frames = try CatAtlas.decode(result)
    precondition(frames.count == 8)
    ImageFixtureProtocol.status = 401
    do {
        _ = try await ImageAPI.generate(photo: image, key: key, model: "test", preview: { _ in }, configuration: config)
        preconditionFailure("HTTP 401 must fail")
    } catch { precondition(error.localizedDescription.contains("Key")) }
    ImageFixtureProtocol.status = 200
    ImageFixtureProtocol.fixture = try event("image_edit.partial_image")
    do {
        _ = try await ImageAPI.generate(photo: image, key: key, model: "test", preview: { _ in }, configuration: config)
        preconditionFailure("Incomplete stream must never replace the pet")
    } catch { precondition(error.localizedDescription.contains("结束")) }
    ImageFixtureProtocol.fixture = Data("data: {\"type\":\"image_edit.failed\"}\n\n".utf8)
    do {
        _ = try await ImageAPI.generate(photo: image, key: key, model: "test", preview: { _ in }, configuration: config)
        preconditionFailure("Failed stream must not produce an image")
    } catch { precondition(error.localizedDescription.contains("未能")) }
    print("PASS: API request contract; chunked SSE preview + completion; atlas decode; HTTP 401; incomplete and failed streams (offline fixtures, no paid API call)")
}
