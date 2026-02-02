import Foundation
import Security

struct PlaneConfiguration: Codable {
  var baseURLString: String
  var workspaceSlug: String
  var apiKey: String?

  static func load() -> PlaneConfiguration {
    let defaults = UserDefaults.standard
    let base = defaults.string(forKey: "plane.baseURL") ?? ""
    let slug = defaults.string(forKey: "plane.workspaceSlug") ?? ""
    let apiKey = Keychain.shared.read(service: "PlaneMobile", account: "apiKey")
    return PlaneConfiguration(baseURLString: base, workspaceSlug: slug, apiKey: apiKey)
  }

  func save() {
    let defaults = UserDefaults.standard
    defaults.set(baseURLString, forKey: "plane.baseURL")
    defaults.set(workspaceSlug, forKey: "plane.workspaceSlug")
    if let apiKey {
      _ = Keychain.shared.save(service: "PlaneMobile", account: "apiKey", secret: apiKey)
    }
  }

  static func validated(baseURLString: String, workspaceSlug: String, apiKey: String?) -> ValidatedConfiguration? {
    let base = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    let slug = workspaceSlug.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      !base.isEmpty,
      !slug.isEmpty,
      let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
      !key.isEmpty,
      let url = URL(string: base)
    else { return nil }

    return ValidatedConfiguration(baseURL: url, workspaceSlug: slug, apiKey: key)
  }
}

struct ValidatedConfiguration {
  let baseURL: URL
  let workspaceSlug: String
  let apiKey: String
}

enum PlaneConfigurationError: LocalizedError {
  case notConfigured
  case missingBaseURL
  case invalidBaseURL
  case missingWorkspaceSlug
  case missingAPIKey

  var errorDescription: String? {
    switch self {
    case .notConfigured: return "Configure your Plane instance first."
    case .missingBaseURL: return "Base URL is required."
    case .invalidBaseURL: return "Base URL is not a valid URL."
    case .missingWorkspaceSlug: return "Workspace slug is required."
    case .missingAPIKey: return "Personal access token is required."
    }
  }
}

