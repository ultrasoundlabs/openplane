import Foundation

final class MockURLProtocol: URLProtocol {
  struct Stub {
    let statusCode: Int
    let headers: [String: String]
    let body: Data

    init(statusCode: Int = 200, headers: [String: String] = ["Content-Type": "application/json"], body: Data) {
      self.statusCode = statusCode
      self.headers = headers
      self.body = body
    }
  }

  nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> Stub)?
  nonisolated(unsafe) static var onRequest: (@Sendable (URLRequest) -> Void)?

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    Self.onRequest?(request)

    guard let handler = Self.handler else {
      client?.urlProtocol(self, didFailWithError: NSError(domain: "MockURLProtocol", code: 0))
      return
    }

    do {
      let stub = try handler(request)
      let url = request.url ?? URL(string: "http://localhost/")!
      let response = HTTPURLResponse(url: url, statusCode: stub.statusCode, httpVersion: "HTTP/1.1", headerFields: stub.headers)!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: stub.body)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
