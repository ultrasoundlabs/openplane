import Foundation
import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
  @Published private(set) var configuration: PlaneConfiguration
  @Published private(set) var currentUser: PlaneUser?

  @Published private(set) var projects: [PlaneProject] = []
  @Published var selectedProject: PlaneProject?

  @Published private(set) var workItemsByProject: [String: [PlaneWorkItem]] = [:]
  @Published private(set) var statesByProject: [String: [PlaneState]] = [:]

  @Published private(set) var lastError: PlaneAPIError?

  private var loadingProjects = false
  private var loadingWorkItems: Set<String> = []
  private var loadingStates: Set<String> = []

  private var api: PlaneAPIClient? {
    guard let config = PlaneConfiguration.validated(
      baseURLString: configuration.baseURLString,
      workspaceSlug: configuration.workspaceSlug,
      apiKey: configuration.apiKey
    ) else { return nil }
    return PlaneAPIClient(baseURL: config.baseURL, apiKey: config.apiKey)
  }

  init() {
    self.configuration = PlaneConfiguration.load()
  }

  var isConfigured: Bool {
    PlaneConfiguration.validated(
      baseURLString: configuration.baseURLString,
      workspaceSlug: configuration.workspaceSlug,
      apiKey: configuration.apiKey
    ) != nil
  }

  var isLoadingProjects: Bool { loadingProjects }
  func isLoadingWorkItems(for projectID: String) -> Bool { loadingWorkItems.contains(projectID) }

  func bootstrap() async {
    guard isConfigured, let api else { return }
    do {
      lastError = nil
      currentUser = try await api.getCurrentUser()
      await loadProjects()
    } catch {
      lastError = error as? PlaneAPIError ?? PlaneAPIError.unknown(error)
    }
  }

  func updateConfiguration(baseURLString: String, workspaceSlug: String, apiKey: String) throws {
    let trimmedBase = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedSlug = workspaceSlug.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedBase.isEmpty else { throw PlaneConfigurationError.missingBaseURL }
    guard !trimmedSlug.isEmpty else { throw PlaneConfigurationError.missingWorkspaceSlug }
    guard !trimmedKey.isEmpty else { throw PlaneConfigurationError.missingAPIKey }
    guard URL(string: trimmedBase) != nil else { throw PlaneConfigurationError.invalidBaseURL }

    configuration.baseURLString = trimmedBase
    configuration.workspaceSlug = trimmedSlug
    configuration.apiKey = trimmedKey
    configuration.save()
  }

  func loadProjects() async {
    guard isConfigured, let api else { return }
    guard !loadingProjects else { return }
    loadingProjects = true
    defer { loadingProjects = false }
    do {
      lastError = nil
      projects = try await api.listProjects(workspaceSlug: configuration.workspaceSlug)
      if selectedProject == nil {
        selectedProject = projects.first
      }
    } catch {
      lastError = error as? PlaneAPIError ?? PlaneAPIError.unknown(error)
    }
  }

  func loadWorkItems(project: PlaneProject) async {
    guard isConfigured, let api else { return }
    guard !loadingWorkItems.contains(project.id) else { return }
    loadingWorkItems.insert(project.id)
    defer { loadingWorkItems.remove(project.id) }
    do {
      lastError = nil
      let items = try await api.listWorkItems(workspaceSlug: configuration.workspaceSlug, projectID: project.id)
      workItemsByProject[project.id] = items
    } catch {
      lastError = error as? PlaneAPIError ?? PlaneAPIError.unknown(error)
    }
  }

  func loadStates(project: PlaneProject) async {
    guard isConfigured, let api else { return }
    guard !loadingStates.contains(project.id) else { return }
    loadingStates.insert(project.id)
    defer { loadingStates.remove(project.id) }
    do {
      lastError = nil
      let states = try await api.listStates(workspaceSlug: configuration.workspaceSlug, projectID: project.id)
      statesByProject[project.id] = states
    } catch {
      lastError = error as? PlaneAPIError ?? PlaneAPIError.unknown(error)
    }
  }

  func workItem(projectID: String, itemID: String) -> PlaneWorkItem? {
    workItemsByProject[projectID]?.first(where: { $0.id == itemID })
  }

  func createWorkItem(project: PlaneProject, name: String, descriptionText: String?, priority: PlanePriority) async throws -> PlaneWorkItem {
    guard isConfigured, let api else { throw PlaneConfigurationError.notConfigured }
    let request = CreateWorkItemRequest(
      name: name,
      descriptionHTML: descriptionText.map { PlaneHTML.simpleParagraph($0) },
      priority: priority
    )
    return try await api.createWorkItem(workspaceSlug: configuration.workspaceSlug, projectID: project.id, body: request)
  }

  func updateWorkItem(project: PlaneProject, workItemID: String, stateID: String?, priority: PlanePriority) async throws {
    guard isConfigured, let api else { throw PlaneConfigurationError.notConfigured }
    let request = UpdateWorkItemRequest(state: stateID, priority: priority)
    let updated = try await api.updateWorkItem(workspaceSlug: configuration.workspaceSlug, projectID: project.id, workItemID: workItemID, body: request)
    if var current = workItemsByProject[project.id], let index = current.firstIndex(where: { $0.id == updated.id }) {
      current[index] = updated
      workItemsByProject[project.id] = current
    }
  }
}

