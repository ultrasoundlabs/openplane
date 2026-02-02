import XCTest
@testable import OpenPlane

final class PlaneWorkItemDecodingTests: XCTestCase {
  func testWorkItemsPageDecodesExpandedAndIDForms() throws {
    let data = FixtureLoader.data("work_items_page.json")
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601

    struct Page<T: Decodable>: Decodable { let results: [T] }
    let page = try decoder.decode(Page<PlaneWorkItem>.self, from: data)
    XCTAssertEqual(page.results.count, 2)

    let first = page.results[0]
    XCTAssertEqual(first.id, "w1")
    XCTAssertEqual(first.state?.name, "Todo")
    XCTAssertEqual(first.stateID, "s1")
    XCTAssertEqual(first.assignees?.first?.id, "u1")
    XCTAssertEqual(first.assigneeIDs?.first, "u1")
    XCTAssertEqual(first.labels?.first?.id, "l1")
    XCTAssertEqual(first.labelIDs?.first, "l1")
    XCTAssertEqual(first.type?.id, "t1")
    XCTAssertEqual(first.typeID, "t1")

    let second = page.results[1]
    XCTAssertEqual(second.id, "w2")
    XCTAssertNil(second.state)
    XCTAssertEqual(second.stateID, "s2")
    XCTAssertNil(second.assignees)
    XCTAssertEqual(second.assigneeIDs, ["u1"])
    XCTAssertEqual(second.labels ?? [], [])
    XCTAssertEqual(second.labelIDs ?? [], [])
    XCTAssertNil(second.type)
    XCTAssertEqual(second.typeID, "t1")
  }
}
