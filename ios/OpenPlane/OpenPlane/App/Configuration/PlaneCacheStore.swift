import Foundation

final class PlaneCacheStore {
  private let fileManager = FileManager.default

  struct CacheEnvelope<T: Codable>: Codable {
    let savedAt: Date
    let value: T
  }

  private var baseDirectory: URL {
    let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let dir = base.appendingPathComponent("OpenPlaneCache", isDirectory: true)
    if !fileManager.fileExists(atPath: dir.path) {
      // Best-effort migration from old cache location.
      let legacy = base.appendingPathComponent("PlaneMobileCache", isDirectory: true)
      if fileManager.fileExists(atPath: legacy.path) {
        try? fileManager.moveItem(at: legacy, to: dir)
      }
      try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir
  }

  func saveProjects(_ projects: [PlaneProject], profileID: UUID) {
    writeEnvelope(projects, to: path(profileID: profileID, components: ["projects.json"]))
  }

  func loadProjects(profileID: UUID, maxAge: TimeInterval) -> (value: [PlaneProject], savedAt: Date)? {
    readEnvelope([PlaneProject].self, from: path(profileID: profileID, components: ["projects.json"]), maxAge: maxAge)
  }

  func saveStates(_ states: [PlaneState], profileID: UUID, projectID: String) {
    writeEnvelope(states, to: path(profileID: profileID, components: ["projects", projectID, "states.json"]))
  }

  func loadStates(profileID: UUID, projectID: String, maxAge: TimeInterval) -> (value: [PlaneState], savedAt: Date)? {
    readEnvelope([PlaneState].self, from: path(profileID: profileID, components: ["projects", projectID, "states.json"]), maxAge: maxAge)
  }

  func saveLabels(_ labels: [PlaneLabel], profileID: UUID, projectID: String) {
    writeEnvelope(labels, to: path(profileID: profileID, components: ["projects", projectID, "labels.json"]))
  }

  func loadLabels(profileID: UUID, projectID: String, maxAge: TimeInterval) -> (value: [PlaneLabel], savedAt: Date)? {
    readEnvelope([PlaneLabel].self, from: path(profileID: profileID, components: ["projects", projectID, "labels.json"]), maxAge: maxAge)
  }

  func saveWorkItemTypes(_ types: [PlaneWorkItemType], profileID: UUID, projectID: String) {
    writeEnvelope(types, to: path(profileID: profileID, components: ["projects", projectID, "types.json"]))
  }

  func loadWorkItemTypes(profileID: UUID, projectID: String, maxAge: TimeInterval) -> (value: [PlaneWorkItemType], savedAt: Date)? {
    readEnvelope([PlaneWorkItemType].self, from: path(profileID: profileID, components: ["projects", projectID, "types.json"]), maxAge: maxAge)
  }

  func saveMembers(_ members: [PlaneMember], profileID: UUID, workspaceSlug: String) {
    writeEnvelope(members, to: path(profileID: profileID, components: ["workspace", workspaceSlug, "members.json"]))
  }

  func loadMembers(profileID: UUID, workspaceSlug: String, maxAge: TimeInterval) -> (value: [PlaneMember], savedAt: Date)? {
    readEnvelope([PlaneMember].self, from: path(profileID: profileID, components: ["workspace", workspaceSlug, "members.json"]), maxAge: maxAge)
  }

  func saveWorkItems(_ items: [PlaneWorkItem], profileID: UUID, projectID: String, filterKey: String) {
    writeEnvelope(items, to: path(profileID: profileID, components: ["projects", projectID, "workItems", "\(filterKey).json"]))
  }

  func loadWorkItems(profileID: UUID, projectID: String, filterKey: String, maxAge: TimeInterval) -> (value: [PlaneWorkItem], savedAt: Date)? {
    readEnvelope([PlaneWorkItem].self, from: path(profileID: profileID, components: ["projects", projectID, "workItems", "\(filterKey).json"]), maxAge: maxAge)
  }

  func invalidateWorkItems(profileID: UUID, projectID: String) {
    let dir = path(profileID: profileID, components: ["projects", projectID, "workItems"])
    try? fileManager.removeItem(at: dir)
  }

  private func path(profileID: UUID, components: [String]) -> URL {
    var url = baseDirectory
      .appendingPathComponent(profileID.uuidString, isDirectory: true)
    for c in components.dropLast() {
      url.appendPathComponent(c, isDirectory: true)
    }
    if !fileManager.fileExists(atPath: url.path) {
      try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    return url.appendingPathComponent(components.last!, isDirectory: false)
  }

  private func writeEnvelope<T: Codable>(_ value: T, to url: URL) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    encoder.keyEncodingStrategy = .convertToSnakeCase
    do {
      let envelope = CacheEnvelope(savedAt: Date(), value: value)
      let data = try encoder.encode(envelope)
      try data.write(to: url, options: [.atomic])
    } catch {
      // best-effort cache; ignore
    }
  }

  private func readEnvelope<T: Codable>(_ type: T.Type, from url: URL, maxAge: TimeInterval) -> (value: T, savedAt: Date)? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    guard let envelope = try? decoder.decode(CacheEnvelope<T>.self, from: data) else { return nil }
    if Date().timeIntervalSince(envelope.savedAt) > maxAge {
      return nil
    }
    return (envelope.value, envelope.savedAt)
  }
}
