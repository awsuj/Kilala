//
//  MockURLProtocol.swift
//  KilalaTests
//
//  Created by Edson John Willie on 11/6/26.
//
//  Sprint 1 QA – lets unit tests exercise APIService without a running backend.
//
//  APIService talks to the network through `URLSession.shared` and a hard-coded
//  base URL. Registering this URLProtocol subclass intercepts every request made
//  through `URLSession.shared`, records it, and answers with a stubbed response,
//  so no production code has to change to make the client testable.
//
//  Only install it from suites nested inside `NetworkTests` (which run serially),
//  and always pair `install` with `uninstall` (use `defer`).
//

import Foundation

final class MockURLProtocol: URLProtocol {

    /// Returns the HTTP status code and raw body to answer a captured request with.
    typealias Handler = @Sendable (URLRequest) throws -> (statusCode: Int, body: Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?
    nonisolated(unsafe) private static var captured: [URLRequest] = []

    // MARK: Test-facing API

    static func install(_ handler: @escaping Handler) {
        lock.withLock {
            self.handler = handler
            captured = []
        }
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    static func uninstall() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        lock.withLock {
            handler = nil
            captured = []
        }
    }

    /// Every request intercepted since `install`, oldest first, with `httpBody` populated.
    static var requests: [URLRequest] { lock.withLock { captured } }

    static var lastRequest: URLRequest? { requests.last }

    /// Convenience: answer every request with the same status and JSON text.
    static func respond(status: Int, json: String) {
        let data = Data(json.utf8)
        install { _ in (status, data) }
    }

    // MARK: URLProtocol

    override class func canInit(with request: URLRequest) -> Bool {
        lock.withLock { handler != nil }
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let request = Self.materializingBody(of: self.request)
        let handler: Handler? = Self.lock.withLock {
            Self.captured.append(request)
            return Self.handler
        }

        guard let handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (status, body) = try handler(request)
            let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json; charset=utf-8"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    /// URLSession moves `httpBody` into `httpBodyStream` before it reaches a protocol.
    /// Copy it back so tests can assert on the payload that would have been sent.
    private static func materializingBody(of request: URLRequest) -> URLRequest {
        guard request.httpBody == nil, let stream = request.httpBodyStream else { return request }
        var copy = request
        var data = Data()
        stream.open()
        defer { stream.close() }
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        copy.httpBody = data
        return copy
    }
}

extension URLRequest {
    /// The request body decoded as a flat JSON object (empty if absent or not JSON).
    var jsonBody: [String: Any] {
        guard let httpBody,
              let object = try? JSONSerialization.jsonObject(with: httpBody) as? [String: Any]
        else { return [:] }
        return object
    }
}
