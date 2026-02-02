import Foundation

enum UIStubServer {
  static func installIfEnabled() {
    guard ProcessInfo.processInfo.environment["OPENPLANE_UI_STUBS"] == "1" else { return }

    OpenPlaneStubURLProtocol.handler = { request in
      let path = request.url?.path ?? ""
      let normalized = path.hasSuffix("/") ? path : path + "/"

      func file(_ name: String) -> Data {
        let ns = name as NSString
        let resource = ns.deletingPathExtension
        let ext = ns.pathExtension.isEmpty ? nil : ns.pathExtension
        let candidates: [URL?] = [
          Bundle.main.url(forResource: resource, withExtension: ext, subdirectory: "UIStubs"),
          Bundle.main.url(forResource: resource, withExtension: ext),
        ]
        for url in candidates.compactMap({ $0 }) {
          if let data = try? Data(contentsOf: url) { return data }
        }
        return Data("{\"detail\":\"missing fixture\"}".utf8)
      }

      // Bootstrap
      if normalized == "/api/v1/users/me/" {
        return .init(body: file("user_me.json"))
      }
      if normalized == "/api/v1/workspaces/my-team/members/" {
        return .init(body: Data("[]".utf8))
      }
      if normalized == "/api/v1/workspaces/my-team/projects/" {
        return .init(body: file("projects.json"))
      }

      // Project metadata
      if normalized == "/api/v1/workspaces/my-team/projects/p1/states/" {
        return .init(body: file("states.json"))
      }
      if normalized == "/api/v1/workspaces/my-team/projects/p1/labels/" {
        return .init(body: Data("[]".utf8))
      }
      if normalized == "/api/v1/workspaces/my-team/projects/p1/work-item-types/" {
        return .init(body: Data("[]".utf8))
      }

      // Work items list + detail
      if normalized == "/api/v1/workspaces/my-team/projects/p1/work-items/" {
        return .init(body: file("work_items_page.json"))
      }
      if normalized == "/api/v1/workspaces/my-team/projects/p1/work-items/w1/" {
        return .init(body: file("work_item_detail.json"))
      }

      return .init(statusCode: 404, body: Data("{\"detail\":\"not found\"}".utf8))
    }
  }
}
