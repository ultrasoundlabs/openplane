import Foundation

struct PlaneAPIClient {
  let baseURL: URL
  let apiKey: String

  private let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    d.dateDecodingStrategy = .iso8601
    return d
  }()

  init(baseURL: URL, apiKey: String) {
    self.baseURL = baseURL
    self.apiKey = apiKey
  }

  func getCurrentUser() async throws -> PlaneUser {
    try await send(.init(method: "GET", path: "/api/v1/users/me/"), as: PlaneUser.self)
  }

  func listProjects(workspaceSlug: String) async throws -> [PlaneProject] {
    let path = "/api/v1/workspaces/\(workspaceSlug)/projects/"
    return try await sendList(.init(method: "GET", path: path), as: PlaneProject.self)
  }

  func listWorkItems(workspaceSlug: String, projectID: String) async throws -> [PlaneWorkItem] {
    let path = "/api/v1/workspaces/\(workspaceSlug)/projects/\(projectID)/work-items/"
    // Ask for state expansion when supported; callers can still decode if not expanded.
    return try await sendList(.init(method: "GET", path: path, query: ["expand": "state"]), as: PlaneWorkItem.self)
  }

  func listStates(workspaceSlug: String, projectID: String) async throws -> [PlaneState] {
    let path = "/api/v1/workspaces/\(workspaceSlug)/projects/\(projectID)/states/"
    return try await sendList(.init(method: "GET", path: path), as: PlaneState.self)
  }

  func createWorkItem(workspaceSlug: String, projectID: String, body: CreateWorkItemRequest) async throws -> PlaneWorkItem {
    let path = "/api/v1/workspaces/\(workspaceSlug)/projects/\(projectID)/work-items/"
    return try await send(.init(method: "POST", path: path, jsonBody: try JSONEncoder.plane.encode(body)), as: PlaneWorkItem.self)
  }

  func updateWorkItem(workspaceSlug: String, projectID: String, workItemID: String, body: UpdateWorkItemRequest) async throws -> PlaneWorkItem {
    let path = "/api/v1/workspaces/\(workspaceSlug)/projects/\(projectID)/work-items/\(workItemID)/"
    return try await send(.init(method: "PATCH", path: path, jsonBody: try JSONEncoder.plane.encode(body)), as: PlaneWorkItem.self)
  }

  private func send<T: Decodable>(_ request: PlaneRequest, as: T.Type) async throws -> T {
    let data = try await sendRaw(request)
    return try decoder.decode(T.self, from: data)
  }

  private func sendList<T: Decodable>(_ request: PlaneRequest, as: T.Type) async throws -> [T] {
    let data = try await sendRaw(request)
    do {
      let page = try decoder.decode(PlaneCursorPage<T>.self, from: data)
      return page.results
    } catch {
      // try { "results": [...] }
      if let wrapper = try? decoder.decode(PlaneResultsWrapper<T>.self, from: data) {
        return wrapper.results
      }
      // try [ ... ]
      return try decoder.decode([T].self, from: data)
    }
  }

  private func sendRaw(_ request: PlaneRequest) async throws -> Data {
    var url = baseURL
    if request.path.hasPrefix("/") {
      url.append(path: String(request.path.dropFirst()))
    } else {
      url.append(path: request.path)
    }

    if !request.query.isEmpty, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
      components.queryItems = request.query
        .sorted(by: { $0.key < $1.key })
        .map { URLQueryItem(name: $0.key, value: $0.value) }
      if let composed = components.url { url = composed }
    }

    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = request.method
    urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    if let body = request.jsonBody {
      urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
      urlRequest.httpBody = body
    }

    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    guard let http = response as? HTTPURLResponse else {
      throw PlaneAPIError.invalidResponse
    }

    if (200..<300).contains(http.statusCode) {
      return data
    }

    if let err = try? decoder.decode(PlaneAPIErrorBody.self, from: data) {
      throw PlaneAPIError.http(status: http.statusCode, body: err)
    }
    throw PlaneAPIError.http(status: http.statusCode, body: nil)
  }
}

struct PlaneRequest {
  let method: String
  let path: String
  var query: [String: String] = [:]
  var jsonBody: Data? = nil

  init(method: String, path: String, query: [String: String] = [:], jsonBody: Data? = nil) {
    self.method = method
    self.path = path
    self.query = query
    self.jsonBody = jsonBody
  }
}

struct PlaneCursorPage<T: Decodable>: Decodable {
  let results: [T]
  let nextCursor: String?
  let prevCursor: String?
  let nextPageResults: Bool?
  let prevPageResults: Bool?
  let count: Int?
  let totalPages: Int?
  let totalResults: Int?
}

struct PlaneResultsWrapper<T: Decodable>: Decodable {
  let results: [T]
}

struct PlaneAPIErrorBody: Decodable {
  let detail: String?
  let message: String?
  let errors: [String: [String]]?

  var bestMessage: String? {
    if let detail, !detail.isEmpty { return detail }
    if let message, !message.isEmpty { return message }
    if let errors, let first = errors.values.first?.first { return first }
    return nil
  }
}

enum PlaneAPIError: Error {
  case invalidResponse
  case http(status: Int, body: PlaneAPIErrorBody?)
  case unknown(Error)

  var userFacingMessage: String {
    switch self {
    case .invalidResponse:
      return "Invalid response from server."
    case let .http(status, body):
      return body?.bestMessage ?? "Request failed (HTTP \(status))."
    case let .unknown(error):
      return error.localizedDescription
    }
  }
}

