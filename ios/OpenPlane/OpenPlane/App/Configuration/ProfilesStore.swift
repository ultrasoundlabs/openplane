import Foundation

@MainActor
final class ProfilesStore: ObservableObject {
  private static let keychainService = "OpenPlane"
  private static let legacyKeychainService = "PlaneMobile"

  private let defaults: UserDefaults
  private let secretStore: SecretStoring

  @Published private(set) var profiles: [PlaneProfile] = []
  @Published var selectedProfileID: UUID?

  init(defaults: UserDefaults = .standard, secretStore: SecretStoring = Keychain.shared) {
    self.defaults = defaults
    self.secretStore = secretStore
    load()
    migrateLegacyIfNeeded()
    if selectedProfileID == nil {
      selectedProfileID = profiles.first?.id
    }
  }

  var selectedProfile: PlaneProfile? {
    guard let selectedProfileID else { return nil }
    return profiles.first(where: { $0.id == selectedProfileID })
  }

  func validatedSelectedProfile() throws -> ValidatedProfile {
    guard let profile = selectedProfile else { throw PlaneProfileError.missingName }

    let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { throw PlaneProfileError.missingName }

    let apiBase = Self.normalizeBaseURLString(profile.apiBaseURLString)
    guard let apiBaseURL = URL(string: apiBase) else { throw PlaneProfileError.invalidAPIBaseURL }

    let webBase = Self.normalizeBaseURLString(profile.webBaseURLString)
    guard let webBaseURL = URL(string: webBase) else { throw PlaneProfileError.invalidWebBaseURL }

    let slug = profile.workspaceSlug.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !slug.isEmpty else { throw PlaneProfileError.missingWorkspaceSlug }

    guard let apiKey = readAPIKey(profileID: profile.id)?.trimmingCharacters(in: .whitespacesAndNewlines),
          !apiKey.isEmpty else { throw PlaneProfileError.missingAPIKey }

    return ValidatedProfile(
      id: profile.id,
      name: name,
      apiBaseURL: apiBaseURL,
      webBaseURL: webBaseURL,
      workspaceSlug: slug,
      apiKey: apiKey,
      workItemPathTemplate: profile.workItemPathTemplate?.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty
    )
  }

  func upsertProfile(_ profile: PlaneProfile, apiKey: String?) throws {
    var updated = profile
    updated.name = updated.name.trimmingCharacters(in: .whitespacesAndNewlines)
    updated.apiBaseURLString = Self.normalizeBaseURLString(updated.apiBaseURLString)
    updated.webBaseURLString = Self.normalizeBaseURLString(updated.webBaseURLString)
    updated.workspaceSlug = updated.workspaceSlug.trimmingCharacters(in: .whitespacesAndNewlines)
    if let t = updated.workItemPathTemplate?.trimmingCharacters(in: .whitespacesAndNewlines), t.isEmpty {
      updated.workItemPathTemplate = nil
    }

    guard !updated.name.isEmpty else { throw PlaneProfileError.missingName }
    guard !updated.apiBaseURLString.isEmpty else { throw PlaneProfileError.missingAPIBaseURL }
    guard URL(string: updated.apiBaseURLString) != nil else { throw PlaneProfileError.invalidAPIBaseURL }
    guard !updated.webBaseURLString.isEmpty else { throw PlaneProfileError.missingWebBaseURL }
    guard URL(string: updated.webBaseURLString) != nil else { throw PlaneProfileError.invalidWebBaseURL }
    guard !updated.workspaceSlug.isEmpty else { throw PlaneProfileError.missingWorkspaceSlug }

    if let apiKey {
      let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedKey.isEmpty else { throw PlaneProfileError.missingAPIKey }
      _ = secretStore.save(service: Self.keychainService, account: apiKeyAccount(for: updated.id), secret: trimmedKey)
    }

    if let index = profiles.firstIndex(where: { $0.id == updated.id }) {
      profiles[index] = updated
    } else {
      profiles.append(updated)
    }
    save()
  }

  func deleteProfile(_ profile: PlaneProfile) {
    profiles.removeAll(where: { $0.id == profile.id })
    secretStore.delete(service: Self.keychainService, account: apiKeyAccount(for: profile.id))
    secretStore.delete(service: Self.legacyKeychainService, account: apiKeyAccount(for: profile.id))
    if selectedProfileID == profile.id {
      selectedProfileID = profiles.first?.id
    }
    save()
  }

  func selectProfile(_ profile: PlaneProfile) {
    selectedProfileID = profile.id
    save()
  }

  func clearAllSecrets() {
    for profile in profiles {
      secretStore.delete(service: Self.keychainService, account: apiKeyAccount(for: profile.id))
      secretStore.delete(service: Self.legacyKeychainService, account: apiKeyAccount(for: profile.id))
    }
  }

  // MARK: - Persistence

  private func load() {
    selectedProfileID = defaults.string(forKey: "plane.selectedProfileID").flatMap(UUID.init)
    if let data = defaults.data(forKey: "plane.profiles"),
       let decoded = try? JSONDecoder().decode([PlaneProfile].self, from: data) {
      profiles = decoded
    } else {
      profiles = []
    }
  }

  private func save() {
    defaults.set(selectedProfileID?.uuidString, forKey: "plane.selectedProfileID")
    if let data = try? JSONEncoder().encode(profiles) {
      defaults.set(data, forKey: "plane.profiles")
    }
  }

  private func migrateLegacyIfNeeded() {
    // Migration from the original single-config storage:
    // - plane.baseURL
    // - plane.workspaceSlug
    // - keychain: service=PlaneMobile account=apiKey
    guard profiles.isEmpty else { return }

    let legacyBase = defaults.string(forKey: "plane.baseURL")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let legacySlug = defaults.string(forKey: "plane.workspaceSlug")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let legacyKey = secretStore.read(service: Self.legacyKeychainService, account: "apiKey")?.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !legacyBase.isEmpty, !legacySlug.isEmpty, let legacyKey, !legacyKey.isEmpty else { return }

    let normalized = Self.normalizeBaseURLString(legacyBase)
    let webBase = normalized.replacingOccurrences(of: "https://api.plane.so", with: "https://app.plane.so")
    let profile = PlaneProfile(
      name: "Default",
      apiBaseURLString: normalized,
      webBaseURLString: webBase,
      workspaceSlug: legacySlug
    )

    profiles = [profile]
    selectedProfileID = profile.id
    _ = secretStore.save(service: Self.keychainService, account: apiKeyAccount(for: profile.id), secret: legacyKey)

    defaults.removeObject(forKey: "plane.baseURL")
    defaults.removeObject(forKey: "plane.workspaceSlug")
    secretStore.delete(service: Self.legacyKeychainService, account: "apiKey")
    save()
  }

  private func apiKeyAccount(for profileID: UUID) -> String {
    "apiKey.\(profileID.uuidString)"
  }

  private func readAPIKey(profileID: UUID) -> String? {
    if let key = secretStore.read(service: Self.keychainService, account: apiKeyAccount(for: profileID)) {
      return key
    }
    if let key = secretStore.read(service: Self.legacyKeychainService, account: apiKeyAccount(for: profileID)) {
      // One-time migration: move into new service.
      _ = secretStore.save(service: Self.keychainService, account: apiKeyAccount(for: profileID), secret: key)
      secretStore.delete(service: Self.legacyKeychainService, account: apiKeyAccount(for: profileID))
      return key
    }
    return nil
  }

  private static func normalizeBaseURLString(_ input: String) -> String {
    var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasSuffix("/") { s.removeLast() }

    // If user pastes an API endpoint, trim it back to the host base.
    for suffix in ["/api/v1", "/api"] {
      if s.hasSuffix(suffix) {
        s = String(s.dropLast(suffix.count))
      }
    }
    if s.hasSuffix("/") { s.removeLast() }
    return s
  }
}
