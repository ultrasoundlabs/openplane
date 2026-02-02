import Foundation

struct PlaneUser: Decodable, Identifiable {
  let id: String
  let email: String?
  let displayName: String?
}

struct PlaneProject: Decodable, Identifiable, Hashable {
  let id: String
  let name: String
  let identifier: String
  let description: String?
}

struct PlaneState: Decodable, Identifiable, Hashable {
  let id: String
  let name: String
  let color: String?
  let group: String?
  let sequence: Int?
}

struct PlaneWorkItem: Decodable, Identifiable, Hashable {
  let id: String
  let name: String?
  let identifier: String?
  let sequenceID: Int?
  let descriptionStripped: String?
  let descriptionHTML: String?
  let priorityRaw: String?
  let stateID: String?
  let state: PlaneState?
  let createdAt: Date?
  let updatedAt: Date?

  var stateName: String? { state?.name }
  var priority: PlanePriority { PlanePriority(rawValue: priorityRaw ?? "") ?? .none }
  var descriptionText: String? { descriptionStripped }

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case identifier
    case sequenceID = "sequenceId"
    case descriptionStripped
    case descriptionHTML = "descriptionHtml"
    case priorityRaw = "priority"
    case state
    case createdAt
    case updatedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decodeIfPresent(String.self, forKey: .name)
    identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
    sequenceID = try container.decodeIfPresent(Int.self, forKey: .sequenceID)
    descriptionStripped = try container.decodeIfPresent(String.self, forKey: .descriptionStripped)
    descriptionHTML = try container.decodeIfPresent(String.self, forKey: .descriptionHTML)
    priorityRaw = try container.decodeIfPresent(String.self, forKey: .priorityRaw)
    createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)

    // `state` can be either a UUID string or an expanded State object.
    if let stateID = try? container.decodeIfPresent(String.self, forKey: .state) {
      self.stateID = stateID
      self.state = nil
    } else if let state = try? container.decodeIfPresent(PlaneState.self, forKey: .state) {
      self.state = state
      self.stateID = state.id
    } else {
      self.state = nil
      self.stateID = nil
    }
  }
}

enum PlanePriority: String, Codable, CaseIterable {
  case none
  case urgent
  case high
  case medium
  case low

  var displayName: String {
    switch self {
    case .none: return "None"
    case .urgent: return "Urgent"
    case .high: return "High"
    case .medium: return "Medium"
    case .low: return "Low"
    }
  }
}

struct CreateWorkItemRequest: Codable {
  let name: String
  let descriptionHTML: String?
  let priority: PlanePriority?

  init(name: String, descriptionHTML: String?, priority: PlanePriority) {
    self.name = name
    self.descriptionHTML = descriptionHTML
    self.priority = priority == .none ? nil : priority
  }
}

struct UpdateWorkItemRequest: Codable {
  let state: String?
  let priority: PlanePriority?

  init(state: String?, priority: PlanePriority) {
    self.state = state
    self.priority = priority == .none ? nil : priority
  }
}

enum PlaneHTML {
  static func simpleParagraph(_ text: String) -> String {
    // Plane expects HTML in `description_html`; keep it minimal and safe.
    let escaped = text
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "'", with: "&#39;")
    return "<p>\(escaped.replacingOccurrences(of: "\n", with: "<br/>"))</p>"
  }
}
