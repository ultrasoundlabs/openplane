import Foundation
@testable import OpenPlane

struct TestClientProvider: PlaneAPIClientProviding {
  let session: URLSession

  func makeClient(apiBaseURL: URL, apiKey: String) -> PlaneAPIClient {
    PlaneAPIClient(baseURL: apiBaseURL, apiKey: apiKey, session: session)
  }
}

