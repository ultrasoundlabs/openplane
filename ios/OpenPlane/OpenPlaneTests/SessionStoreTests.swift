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
    // Use an isolated defaults suite so tests don't pollute local app data.
    let suiteName = "OpenPlaneTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let session = MockURLSessionFactory.make()
    let provider = TestClientProvider(session: session)

    let recorder = RequestRecorder()
    MockURLProtocol.onRequest = { request in
      recorder.record(request)
    }

    // Seed a profile + token into storage via ProfilesStore API.
    let profiles = ProfilesStore(defaults: defaults, secretStore: InMemorySecretStore())
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

  func testRefreshWorkItemsEnforcesStateFilterClientSideWhenServerIgnoresQuery() async throws {
    let suiteName = "OpenPlaneTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let session = MockURLSessionFactory.make()
    let provider = TestClientProvider(session: session)

    let recorder = RequestRecorder()
    MockURLProtocol.onRequest = { request in recorder.record(request) }

    let profiles = ProfilesStore(defaults: defaults, secretStore: InMemorySecretStore())
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

    MockURLProtocol.handler = { request in
      let path = request.url?.path ?? ""
      let normalized = path.hasSuffix("/") ? path : path + "/"
      if normalized == "/api/v1/users/me/" { return .init(body: FixtureLoader.data("user_me.json")) }
      if normalized == "/api/v1/workspaces/my-team/projects/" { return .init(body: FixtureLoader.data("projects.json")) }
      if normalized == "/api/v1/workspaces/my-team/projects/p1/work-items/" {
        // Return a mixed page regardless of query params. SessionStore should enforce filters client-side.
        return .init(body: FixtureLoader.data("work_items_page.json"))
      }
      return .init(statusCode: 404, body: Data("{\"detail\":\"not found\"}".utf8))
    }

    await store.bootstrap()
    let project = try XCTUnwrap(store.projects.first)

    await store.refreshWorkItems(project: project, stateID: "s1", mineOnly: false, replaceExisting: true)

    let key = "workItems|project=\(project.id)|state=s1|assignee="
    let filtered = store.workItemsByKey[key] ?? []
    XCTAssertEqual(filtered.map(\.id), ["w1"], "filtered list should only contain items in the selected state\nrequests:\n\(recorder.dump())")
  }

  func testLoadMoreWorkItemsDoesNotSendRequestForInactiveFilter() async throws {
    let suiteName = "OpenPlaneTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let session = MockURLSessionFactory.make()
    let provider = TestClientProvider(session: session)

    let recorder = RequestRecorder()
    MockURLProtocol.onRequest = { request in recorder.record(request) }

    let profiles = ProfilesStore(defaults: defaults, secretStore: InMemorySecretStore())
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

    MockURLProtocol.handler = { request in
      let path = request.url?.path ?? ""
      let normalized = path.hasSuffix("/") ? path : path + "/"
      if normalized == "/api/v1/users/me/" { return .init(body: FixtureLoader.data("user_me.json")) }
      if normalized == "/api/v1/workspaces/my-team/projects/" { return .init(body: FixtureLoader.data("projects.json")) }
      if normalized == "/api/v1/workspaces/my-team/projects/p1/work-items/" { return .init(body: FixtureLoader.data("work_items_page.json")) }
      return .init(statusCode: 404, body: Data("{\"detail\":\"not found\"}".utf8))
    }

    await store.bootstrap()
    let project = try XCTUnwrap(store.projects.first)

    // Establish an active filter with state=s1.
    await store.refreshWorkItems(project: project, stateID: "s1", mineOnly: false, replaceExisting: true)
    let before = recorder.dump()

    // Attempt to load more for a different state. This should return early and not hit the network.
    await store.loadMoreWorkItems(project: project, stateID: "s2", mineOnly: false)
    let after = recorder.dump()

    XCTAssertEqual(after, before, "loadMoreWorkItems for an inactive filter should not send requests")
  }
}
