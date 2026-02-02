import Foundation

struct PlaneProfile: Codable, Identifiable, Hashable {
  let id: UUID
  var name: String
  var apiBaseURLString: String
  var webBaseURLString: String
  var workspaceSlug: String
  var workItemPathTemplate: String?

  init(
    id: UUID = UUID(),
    name: String,
    apiBaseURLString: String,
    webBaseURLString: String,
    workspaceSlug: String,
    workItemPathTemplate: String? = nil
  ) {
    self.id = id
    self.name = name
    self.apiBaseURLString = apiBaseURLString
    self.webBaseURLString = webBaseURLString
    self.workspaceSlug = workspaceSlug
    self.workItemPathTemplate = workItemPathTemplate
  }
}

struct ValidatedProfile {
  let id: UUID
  let name: String
  let apiBaseURL: URL
  let webBaseURL: URL
  let workspaceSlug: String
  let apiKey: String
  let workItemPathTemplate: String?
}

enum PlaneProfileError: LocalizedError {
  case missingName
  case missingAPIBaseURL
  case invalidAPIBaseURL
  case missingWebBaseURL
  case invalidWebBaseURL
  case missingWorkspaceSlug
  case missingAPIKey

  var errorDescription: String? {
    switch self {
    case .missingName: return "Profile name is required."
    case .missingAPIBaseURL: return "API Base URL is required."
    case .invalidAPIBaseURL: return "API Base URL is not a valid URL."
    case .missingWebBaseURL: return "Web Base URL is required."
    case .invalidWebBaseURL: return "Web Base URL is not a valid URL."
    case .missingWorkspaceSlug: return "Workspace slug is required."
    case .missingAPIKey: return "Personal access token is required."
    }
  }
}
