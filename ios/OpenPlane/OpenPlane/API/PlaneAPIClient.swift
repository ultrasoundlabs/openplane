import Foundation

struct PlaneAPIClient {
  let baseURL: URL
  let apiKey: String
  let session: URLSession
  let timeoutSeconds: TimeInterval

  private let maxRetries = 3

  private let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    d.dateDecodingStrategy = .iso8601
    return d
  }()

  init(baseURL: URL, apiKey: String, session: URLSession = .shared, timeoutSeconds: TimeInterval = 20) {
    self.baseURL = baseURL
    self.apiKey = apiKey
    self.session = session
    self.timeoutSeconds = timeoutSeconds
  }

  func getCurrentUser() async throws -> PlaneUser {
    try await send(.init(method: "GET", path: "/api/v1/users/me/"), as: PlaneUser.self)
  }

  func listProjects(workspaceSlug: String) async throws -> [PlaneProject] {
    let path = "/api/v1/workspaces/\(workspaceSlug)/projects/"
    return try await sendList(.init(method: "GET", path: path), as: PlaneProject.self)
  }

  func listWorkItems(workspaceSlug: String, projectID: String) async throws -> [PlaneWorkItem] {
    try await listWorkItems(workspaceSlug: workspaceSlug, projectID: projectID, filter: .init())
  }

  struct WorkItemsFilter: Hashable {
    var stateID: String?
    var assigneeID: String?
    var search: String?
    var limit: Int? = 50
    var offset: Int? = nil
    var expand: String = "state,assignees,labels,type"

    init(stateID: String? = nil, assigneeID: String? = nil, search: String? = nil, limit: Int? = 50, offset: Int? = nil) {
      self.stateID = stateID
      self.assigneeID = assigneeID
      self.search = search
      self.limit = limit
      self.offset = offset
    }
  }

  func listWorkItems(workspaceSlug: String, projectID: String, filter: WorkItemsFilter) async throws -> [PlaneWorkItem] {
    let path = "/api/v1/workspaces/\(workspaceSlug)/projects/\(projectID)/work-items/"
    var query: [String: String] = [:]
    if let stateID = filter.stateID { query["state"] = stateID }
    if let assigneeID = filter.assigneeID { query["assignee"] = assigneeID }
    if let limit = filter.limit { query["limit"] = String(limit) }
    if let offset = filter.offset { query["offset"] = String(offset) }
    if !filter.expand.isEmpty { query["expand"] = filter.expand }
    return try await sendList(.init(method: "GET", path: path, query: query), as: PlaneWorkItem.self)
  }

  func listStates(workspaceSlug: String, projectID: String) async throws -> [PlaneState] {
    let path = "/api/v1/workspaces/\(workspaceSlug)/projects/\(projectID)/states/"
    return try await sendList(.init(method: "GET", path: path), as: PlaneState.self)
  }

  func listLabels(workspaceSlug: String, projectID: String) async throws -> [PlaneLabel] {
    let path = "/api/v1/workspaces/\(workspaceSlug)/projects/\(projectID)/labels/"
    return try await sendList(.init(method: "GET", path: path), as: PlaneLabel.self)
  }

  func listWorkItemTypes(workspaceSlug: String, projectID: String) async throws -> [PlaneWorkItemType] {
    let path = "/api/v1/workspaces/\(workspaceSlug)/projects/\(projectID)/work-item-types/"
    return try await sendList(.init(method: "GET", path: path), as: PlaneWorkItemType.self)
  }

  func listMembers(workspaceSlug: String) async throws -> [PlaneMember] {
    let path = "/api/v1/workspaces/\(workspaceSlug)/members/"
    return try await sendList(.init(method: "GET", path: path), as: PlaneMember.self)
  }

  func searchWorkItems(workspaceSlug: String, search: String, projectID: String?) async throws -> [PlaneWorkItem] {
    let path = "/api/v1/workspaces/\(workspaceSlug)/work-items/search/"
    var query: [String: String] = ["search": search, "expand": "state,assignees,labels,type,project"]
    if let projectID { query["project"] = projectID }
    return try await sendList(.init(method: "GET", path: path, query: query), as: PlaneWorkItem.self)
  }

  func getWorkItemDetail(workspaceSlug: String, projectID: String, workItemID: String) async throws -> PlaneWorkItem {
    let path = "/api/v1/workspaces/\(workspaceSlug)/projects/\(projectID)/work-items/\(workItemID)/"
    return try await send(.init(method: "GET", path: path, query: ["expand": "state,assignees,labels,type,project"]), as: PlaneWorkItem.self)
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
    try await sendRaw(request, attempt: 0)
  }

  private func sendRaw(_ request: PlaneRequest, attempt: Int) async throws -> Data {
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
    urlRequest.timeoutInterval = timeoutSeconds
    urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    if let body = request.jsonBody {
      urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
      urlRequest.httpBody = body
    }

    let (data, response): (Data, URLResponse)
    do {
      (data, response) = try await session.data(for: urlRequest)
    } catch {
      if attempt < maxRetries {
        let delay = backoffDelaySeconds(attempt: attempt, base: 0.5, max: 5.0)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return try await sendRaw(request, attempt: attempt + 1)
      }
      throw PlaneAPIError.transport(error, endpoint: PlaneEndpoint(method: request.method, url: url))
    }
    guard let http = response as? HTTPURLResponse else {
      throw PlaneAPIError.invalidResponse
    }

    if (200..<300).contains(http.statusCode) {
      return data
    }

    if http.statusCode == 429, attempt < maxRetries {
      let delay = retryDelaySeconds(from: http) ?? backoffDelaySeconds(attempt: attempt, base: 1.0, max: 10.0)
      try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      return try await sendRaw(request, attempt: attempt + 1)
    }

    if (500..<600).contains(http.statusCode), attempt < maxRetries {
      let delay = backoffDelaySeconds(attempt: attempt, base: 0.5, max: 5.0)
      try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      return try await sendRaw(request, attempt: attempt + 1)
    }

    if let err = try? decoder.decode(PlaneAPIErrorBody.self, from: data) {
      throw PlaneAPIError.http(status: http.statusCode, body: err, endpoint: PlaneEndpoint(method: request.method, url: url))
    }
    throw PlaneAPIError.http(status: http.statusCode, body: nil, endpoint: PlaneEndpoint(method: request.method, url: url))
  }

  private func retryDelaySeconds(from response: HTTPURLResponse) -> Double? {
    let headers = response.allHeaderFields
    if let retryAfter = headers["Retry-After"] as? String, let seconds = Double(retryAfter) {
      return max(0.0, seconds)
    }
    if let reset = headers["X-RateLimit-Reset"] as? String, let epoch = Double(reset) {
      let now = Date().timeIntervalSince1970
      return max(0.5, epoch - now)
    }
    return nil
  }

  private func backoffDelaySeconds(attempt: Int, base: Double, max: Double) -> Double {
    // Deterministic exponential backoff.
    min(max, base * pow(2.0, Double(attempt)))
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
  case http(status: Int, body: PlaneAPIErrorBody?, endpoint: PlaneEndpoint?)
  case transport(Error, endpoint: PlaneEndpoint?)
  case unknown(Error)

  var userFacingMessage: String {
    switch self {
    case .invalidResponse:
      return "Invalid response from server."
    case let .http(status, body, _):
      if status == 401 { return body?.bestMessage ?? "Unauthorized (HTTP 401). Check your Personal Access Token." }
      if status == 403 { return body?.bestMessage ?? "Forbidden (HTTP 403). Your token may not have access to this workspace." }
      if status == 404 { return body?.bestMessage ?? "Not found (HTTP 404). Check the workspace slug and base URL." }
      return body?.bestMessage ?? "Request failed (HTTP \(status))."
    case let .transport(error, _):
      return error.localizedDescription
    case let .unknown(error):
      return error.localizedDescription
    }
  }

  var isAuthError: Bool {
    switch self {
    case let .http(status, _, _):
      return status == 401 || status == 403
    default:
      return false
    }
  }

  var diagnostics: String? {
    switch self {
    case let .http(status, body, endpoint):
      var lines: [String] = []
      if let endpoint { lines.append("\(endpoint.method) \(endpoint.url.absoluteString)") }
      lines.append("HTTP \(status)")
      if let msg = body?.bestMessage, !msg.isEmpty { lines.append(msg) }
      return lines.joined(separator: "\n")
    case let .transport(error, endpoint):
      var lines: [String] = []
      if let endpoint { lines.append("\(endpoint.method) \(endpoint.url.absoluteString)") }
      lines.append("Transport error")
      lines.append(error.localizedDescription)
      return lines.joined(separator: "\n")
    default:
      return nil
    }
  }
}

struct PlaneEndpoint: Sendable {
  let method: String
  let url: URL
}
