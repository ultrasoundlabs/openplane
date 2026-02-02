import Foundation
import XCTest
@testable import OpenPlane

@MainActor
final class SessionStoreTests: XCTestCase {
  private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [String] = []

    func record(_ request: URLRequest) {
      let method = request.httpMethod ?? "?"
      let url = request.url?.absoluteString ?? "(nil)"
      lock.lock()
      requests.append("\(method) \(url)")
      lock.unlock()
    }

    func dump() -> String {
      lock.lock()
      let out = requests.joined(separator: "\n")
      lock.unlock()
      return out
    }
  }

  override func tearDown() {
    MockURLProtocol.handler = nil
    MockURLProtocol.onRequest = nil
    super.tearDown()
  }

  func testBootstrapLoadsUserThenProjects() async throws {
    UserDefaults.standard.removeObject(forKey: "plane.selectedProfileID")
    UserDefaults.standard.removeObject(forKey: "plane.profiles")
    Keychain.shared.deleteAll(service: "OpenPlane")
    Keychain.shared.deleteAll(service: "PlaneMobile")

    let session = MockURLSessionFactory.make()
    let provider = TestClientProvider(session: session)

    let recorder = RequestRecorder()
    MockURLProtocol.onRequest = { request in
      recorder.record(request)
    }

    // Seed a profile + token into storage via ProfilesStore API.
    let profiles = ProfilesStore(secretStore: InMemorySecretStore())
    let profile = PlaneProfile(
      name: "Test",
      apiBaseURLString: "https://example.test",
      webBaseURLString: "https://example.test",
      workspaceSlug: "my-team",
      workItemPathTemplate: "/{workspaceSlug}/work-items/{identifier}"
    )
    try profiles.upsertProfile(profile, apiKey: "plane_api_test")
    profiles.selectProfile(profile)

    let store = SessionStore(profiles: profiles, clientProvider: provider)

    XCTAssertTrue(store.isConfigured)
    // Ensure profile validation still succeeds right before bootstrap (helps catch keychain / persistence issues).
    XCTAssertNoThrow(try profiles.validatedSelectedProfile())

    MockURLProtocol.handler = { request in
      let path = request.url?.path ?? ""
      let normalized = path.hasSuffix("/") ? path : path + "/"
      if normalized == "/api/v1/users/me/" {
        return .init(body: FixtureLoader.data("user_me.json"))
      }
      if normalized == "/api/v1/workspaces/my-team/members/" {
        return .init(body: Data("[]".utf8))
      }
      if normalized == "/api/v1/workspaces/my-team/projects/" {
        return .init(body: FixtureLoader.data("projects.json"))
      }
      return .init(statusCode: 404, body: Data("{\"detail\":\"not found\"}".utf8))
    }

    await store.bootstrap()

    if let lastError = store.lastError {
      XCTFail("bootstrap failed: \(lastError.userFacingMessage)\nrequests:\n\(recorder.dump())")
    }
    if store.currentUser == nil || store.projects.isEmpty {
      XCTFail("bootstrap produced empty state (isConfigured=\(store.isConfigured))\nrequests:\n\(recorder.dump())")
    }
    XCTAssertEqual(store.currentUser?.id, "u1")
    XCTAssertEqual(store.projects.count, 1)
    XCTAssertEqual(store.projects.first?.id, "p1")
  }
}
