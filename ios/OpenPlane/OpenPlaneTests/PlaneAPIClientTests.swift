import XCTest
@testable import OpenPlane

final class PlaneAPIClientTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.handler = nil
    super.tearDown()
  }

  func testListProjectsSendsXAPIKeyHeader() async throws {
    let session = MockURLSessionFactory.make()
    let client = PlaneAPIClient(baseURL: URL(string: "https://example.test")!, apiKey: "plane_api_test", session: session)

    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "plane_api_test")
      return .init(body: FixtureLoader.data("projects.json"))
    }

    let projects = try await client.listProjects(workspaceSlug: "my-team")
    XCTAssertEqual(projects.count, 1)
    XCTAssertEqual(projects[0].identifier, "PROJ1")
  }

  func testWorkItemDetailDecodes() async throws {
    let session = MockURLSessionFactory.make()
    let client = PlaneAPIClient(baseURL: URL(string: "https://example.test")!, apiKey: "k", session: session)

    MockURLProtocol.handler = { request in
      let path = request.url?.path ?? ""
      XCTAssertTrue(path.contains("/work-items/"))
      XCTAssertTrue(path.contains("/w1"))
      return .init(body: FixtureLoader.data("work_item_detail.json"))
    }

    let item = try await client.getWorkItemDetail(workspaceSlug: "my-team", projectID: "p1", workItemID: "w1")
    XCTAssertEqual(item.id, "w1")
    XCTAssertEqual(item.stateID, "s1")
    XCTAssertEqual(item.assigneeIDs?.first, "u1")
  }
}
