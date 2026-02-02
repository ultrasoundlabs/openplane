import Foundation

protocol PlaneAPIClientProviding: Sendable {
  func makeClient(apiBaseURL: URL, apiKey: String) -> PlaneAPIClient
}

struct DefaultPlaneAPIClientProvider: PlaneAPIClientProviding {
  let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func makeClient(apiBaseURL: URL, apiKey: String) -> PlaneAPIClient {
    PlaneAPIClient(baseURL: apiBaseURL, apiKey: apiKey, session: session)
  }
}
