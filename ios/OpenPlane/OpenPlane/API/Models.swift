import Foundation

struct PlaneUser: Codable, Identifiable {
  let id: String
  let email: String?
  let displayName: String?
}

struct PlaneProject: Codable, Identifiable, Hashable {
  let id: String
  let name: String
  let identifier: String
  let description: String?
}

struct PlaneMember: Codable, Identifiable, Hashable {
  let id: String
  let firstName: String?
  let lastName: String?
  let email: String?
  let avatarURL: String?
  let displayName: String?
  let role: Int?

  var bestName: String {
    if let displayName, !displayName.isEmpty { return displayName }
    let fn = firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let ln = lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let full = [fn, ln].filter { !$0.isEmpty }.joined(separator: " ")
    if !full.isEmpty { return full }
    return email ?? id
  }
}

struct PlaneState: Codable, Identifiable, Hashable {
  let id: String
  let name: String
  let color: String?
  let group: String?
  let sequence: Int?
}

struct PlaneLabel: Codable, Identifiable, Hashable {
  let id: String
  let name: String?
  let color: String?
}

struct PlaneWorkItemType: Codable, Identifiable, Hashable {
  let id: String
  let name: String?
}

struct PlaneWorkItem: Codable, Identifiable, Hashable {
  let id: String
  let name: String?
  let identifier: String?
  let sequenceID: Int?
  let descriptionStripped: String?
  let descriptionHTML: String?
  let priorityRaw: String?
  let stateID: String?
  let state: PlaneState?
  let assignees: [PlaneMember]?
  let assigneeIDs: [String]?
  let labels: [PlaneLabel]?
  let labelIDs: [String]?
  let typeID: String?
  let type: PlaneWorkItemType?
  let startDate: String?
  let targetDate: String?
  let createdAt: Date?
  let updatedAt: Date?

  var stateName: String? { state?.name }
  var priority: PlanePriority { PlanePriority(rawValue: priorityRaw ?? "") ?? .none }
  var descriptionText: String? {
    if let s = descriptionStripped?.trimmedNonEmpty { return s }
    if let html = descriptionHTML?.trimmedNonEmpty {
      return PlaneHTML.plainText(html).trimmedNonEmpty
    }
    return nil
  }
  var assigneeNames: String {
    let names = (assignees ?? []).map(\.bestName).filter { !$0.isEmpty }
    return names.joined(separator: ", ")
  }

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case identifier
    case sequenceID = "sequenceId"
    case descriptionStripped
    case descriptionHTML = "descriptionHtml"
    case priorityRaw = "priority"
    case state
    case assignees
    case labels
    case type
    case startDate
    case targetDate
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
    startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
    targetDate = try container.decodeIfPresent(String.self, forKey: .targetDate)

    if let expanded = try? container.decodeIfPresent([PlaneMember].self, forKey: .assignees) {
      assignees = expanded
      assigneeIDs = expanded.map(\.id)
    } else if let ids = try? container.decodeIfPresent([String].self, forKey: .assignees) {
      assignees = nil
      assigneeIDs = ids
    } else {
      assignees = nil
      assigneeIDs = nil
    }

    if let expanded = try? container.decodeIfPresent([PlaneLabel].self, forKey: .labels) {
      labels = expanded
      labelIDs = expanded.map(\.id)
    } else if let ids = try? container.decodeIfPresent([String].self, forKey: .labels) {
      labels = nil
      labelIDs = ids
    } else {
      labels = nil
      labelIDs = nil
    }

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

    // `type` can be either a UUID string or an expanded WorkItemType object.
    if let typeID = try? container.decodeIfPresent(String.self, forKey: .type) {
      self.typeID = typeID
      self.type = nil
    } else if let type = try? container.decodeIfPresent(PlaneWorkItemType.self, forKey: .type) {
      self.type = type
      self.typeID = type.id
    } else {
      self.type = nil
      self.typeID = nil
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encodeIfPresent(name, forKey: .name)
    try container.encodeIfPresent(identifier, forKey: .identifier)
    try container.encodeIfPresent(sequenceID, forKey: .sequenceID)
    try container.encodeIfPresent(descriptionStripped, forKey: .descriptionStripped)
    try container.encodeIfPresent(descriptionHTML, forKey: .descriptionHTML)
    try container.encodeIfPresent(priorityRaw, forKey: .priorityRaw)
    if let assignees {
      try container.encode(assignees, forKey: .assignees)
    } else {
      try container.encodeIfPresent(assigneeIDs, forKey: .assignees)
    }
    if let labels {
      try container.encode(labels, forKey: .labels)
    } else {
      try container.encodeIfPresent(labelIDs, forKey: .labels)
    }
    try container.encodeIfPresent(startDate, forKey: .startDate)
    try container.encodeIfPresent(targetDate, forKey: .targetDate)
    try container.encodeIfPresent(createdAt, forKey: .createdAt)
    try container.encodeIfPresent(updatedAt, forKey: .updatedAt)

    if let state {
      try container.encode(state, forKey: .state)
    } else {
      try container.encodeIfPresent(stateID, forKey: .state)
    }

    if let type {
      try container.encode(type, forKey: .type)
    } else {
      try container.encodeIfPresent(typeID, forKey: .type)
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

struct CreateWorkItemRequest: Codable, Sendable {
  let name: String
  let descriptionHTML: String?
  let state: String?
  let priority: PlanePriority?
  let assignees: [String]?
  let labels: [String]?
  let type: String?
  let startDate: String?
  let targetDate: String?

  init(
    name: String,
    descriptionHTML: String?,
    state: String? = nil,
    priority: PlanePriority?,
    assignees: [String]? = nil,
    labels: [String]? = nil,
    type: String? = nil,
    startDate: String? = nil,
    targetDate: String? = nil
  ) {
    self.name = name
    self.descriptionHTML = descriptionHTML
    self.state = state
    self.priority = priority == PlanePriority.none ? nil : priority
    self.assignees = assignees
    self.labels = labels
    self.type = type
    self.startDate = startDate
    self.targetDate = targetDate
  }
}

struct UpdateWorkItemRequest: Encodable, Sendable {
  let state: String?
  let priority: PlanePriority?
  let assignees: [String]?
  let labels: [String]?
  let type: String?
  let startDate: PlanePatchField<String>
  let targetDate: PlanePatchField<String>
  let name: String?
  let descriptionHTML: String?

  init(
    name: String? = nil,
    descriptionHTML: String? = nil,
    state: String?,
    priority: PlanePriority,
    assignees: [String]? = nil,
    labels: [String]? = nil,
    type: String? = nil,
    startDate: PlanePatchField<String> = .unset,
    targetDate: PlanePatchField<String> = .unset
  ) {
    self.name = name
    self.descriptionHTML = descriptionHTML
    self.state = state
    self.priority = priority == PlanePriority.none ? nil : priority
    self.assignees = assignees
    self.labels = labels
    self.type = type
    self.startDate = startDate
    self.targetDate = targetDate
  }

  enum CodingKeys: String, CodingKey {
    case name
    case descriptionHTML
    case state
    case priority
    case assignees
    case labels
    case type
    case startDate
    case targetDate
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(name, forKey: .name)
    try container.encodeIfPresent(descriptionHTML, forKey: .descriptionHTML)
    try container.encodeIfPresent(state, forKey: .state)
    try container.encodeIfPresent(priority, forKey: .priority)
    try container.encodeIfPresent(assignees, forKey: .assignees)
    try container.encodeIfPresent(labels, forKey: .labels)
    try container.encodeIfPresent(type, forKey: .type)

    switch startDate {
    case .unset:
      break
    case .null:
      try container.encodeNil(forKey: .startDate)
    case let .value(value):
      try container.encode(value, forKey: .startDate)
    }

    switch targetDate {
    case .unset:
      break
    case .null:
      try container.encodeNil(forKey: .targetDate)
    case let .value(value):
      try container.encode(value, forKey: .targetDate)
    }
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

  static func plainText(_ html: String) -> String {
    // Best-effort conversion for displaying `description_html` in list/detail views.
    // Avoid NSAttributedString(html:) here: it can be expensive and has been observed to
    // trigger UIKit/SwiftUI collection-view assertion crashes under load.
    var s = html

    // Newlines for common block separators.
    s = s.replacingOccurrences(of: "(?i)<br\\s*/?>", with: "\n", options: .regularExpression)
    s = s.replacingOccurrences(of: "(?i)</(p|div|li|ul|ol|h1|h2|h3|h4|h5|h6)>", with: "\n", options: .regularExpression)

    // Strip remaining tags.
    s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

    // Decode HTML entities (best-effort, supports common + numeric entities).
    s = decodeHTMLEntities(s)

    // Normalize whitespace.
    s = s.replacingOccurrences(of: "\r\n", with: "\n")
    s = s.replacingOccurrences(of: "\r", with: "\n")
    s = s.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func decodeHTMLEntities(_ input: String) -> String {
    var s = input
    let common: [String: String] = [
      "&amp;": "&",
      "&lt;": "<",
      "&gt;": ">",
      "&quot;": "\"",
      "&#39;": "'",
      "&apos;": "'",
      "&nbsp;": " ",
    ]
    for (k, v) in common {
      s = s.replacingOccurrences(of: k, with: v)
    }

    // Numeric decimal: &#1234;
    s = replaceRegexMatches(in: s, pattern: "&#(\\d+);") { groups in
      guard let dec = Int(groups[0], radix: 10), let scalar = UnicodeScalar(dec) else { return nil }
      return String(scalar)
    }

    // Numeric hex: &#x1F600;
    s = replaceRegexMatches(in: s, pattern: "&#x([0-9A-Fa-f]+);") { groups in
      guard let hex = Int(groups[0], radix: 16), let scalar = UnicodeScalar(hex) else { return nil }
      return String(scalar)
    }

    return s
  }

  private static func replaceRegexMatches(in input: String, pattern: String, transform: ([String]) -> String?) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
    let ns = input as NSString
    let matches = regex.matches(in: input, range: NSRange(location: 0, length: ns.length))
    if matches.isEmpty { return input }

    let out = NSMutableString(string: input)
    for match in matches.reversed() {
      var groups: [String] = []
      if match.numberOfRanges > 1 {
        for idx in 1..<match.numberOfRanges {
          let r = match.range(at: idx)
          if r.location != NSNotFound {
            groups.append(ns.substring(with: r))
          } else {
            groups.append("")
          }
        }
      }
      if let replacement = transform(groups) {
        out.replaceCharacters(in: match.range, with: replacement)
      }
    }
    return out as String
  }
}

enum PlanePatchField<T: Encodable & Sendable>: Encodable, Sendable {
  case unset
  case null
  case value(T)

  func encode(to encoder: Encoder) throws {
    // This is only used when a field is explicitly encoded by the parent.
    var container = encoder.singleValueContainer()
    switch self {
    case .unset:
      try container.encodeNil()
    case .null:
      try container.encodeNil()
    case let .value(value):
      try container.encode(value)
    }
  }
}
