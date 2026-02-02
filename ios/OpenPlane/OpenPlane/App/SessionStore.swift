import Foundation
import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
  @Published private(set) var currentUser: PlaneUser?
  @Published private(set) var currentProfile: ValidatedProfile?

  @Published private(set) var projects: [PlaneProject] = []
  @Published var selectedProject: PlaneProject?

  @Published private(set) var workItemsByProject: [String: [PlaneWorkItem]] = [:]
  @Published private(set) var workItemsMetaByKey: [String: WorkItemsMeta] = [:]
  @Published private(set) var lastRefreshedByKey: [String: Date] = [:]
  @Published private(set) var statesByProject: [String: [PlaneState]] = [:]
  @Published private(set) var labelsByProject: [String: [PlaneLabel]] = [:]
  @Published private(set) var workItemTypesByProject: [String: [PlaneWorkItemType]] = [:]
  @Published private(set) var membersByWorkspace: [String: [PlaneMember]] = [:]

  @Published private(set) var lastError: PlaneAPIError?

  private var loadingProjects = false
  private var loadingWorkItems: Set<String> = []
  private var loadingStates: Set<String> = []
  private var loadingLabels: Set<String> = []
  private var loadingTypes: Set<String> = []
  private var loadingMembers: Set<String> = []

  private let profiles: ProfilesStore
  private let cache: PlaneCacheStore
  private let clientProvider: PlaneAPIClientProviding

  init(profiles: ProfilesStore, clientProvider: PlaneAPIClientProviding = DefaultPlaneAPIClientProvider()) {
    self.profiles = profiles
    self.cache = PlaneCacheStore()
    self.clientProvider = clientProvider
    hydrateFromCache()
  }

  var isConfigured: Bool {
    (try? profiles.validatedSelectedProfile()) != nil
  }

  var isLoadingProjects: Bool { loadingProjects }
  func isLoadingWorkItems(for projectID: String) -> Bool { loadingWorkItems.contains(projectID) }
  func workItemsMeta(forKey key: String) -> WorkItemsMeta { workItemsMetaByKey[key] ?? WorkItemsMeta() }
  func lastRefreshed(forKey key: String) -> Date? { lastRefreshedByKey[key] }

  private func apiClient() throws -> (PlaneAPIClient, ValidatedProfile) {
    let profile = try profiles.validatedSelectedProfile()
    return (clientProvider.makeClient(apiBaseURL: profile.apiBaseURL, apiKey: profile.apiKey), profile)
  }

  func bootstrap() async {
    guard isConfigured else { return }
    do {
      lastError = nil
      let (api, profile) = try apiClient()
      currentProfile = profile
      currentUser = try await api.getCurrentUser()
      await loadMembers()
      await loadProjects()
    } catch {
      let apiError = error as? PlaneAPIError ?? PlaneAPIError.unknown(error)
      lastError = apiError
      if apiError.isAuthError {
        currentUser = nil
        projects = []
        selectedProject = nil
      }
    }
  }

  func testConnection() async throws -> PlaneUser {
    let (api, profile) = try apiClient()
    let user = try await api.getCurrentUser()
    _ = try await api.listProjects(workspaceSlug: profile.workspaceSlug)
    return user
  }

  func loadProjects() async {
    guard isConfigured else { return }
    guard !loadingProjects else { return }
    loadingProjects = true
    defer { loadingProjects = false }
    do {
      lastError = nil
      let (api, profile) = try apiClient()
      projects = try await api.listProjects(workspaceSlug: profile.workspaceSlug)
      cache.saveProjects(projects, profileID: profile.id)
      lastRefreshedByKey["projects"] = Date()
      if selectedProject == nil {
        selectedProject = projects.first
      }
    } catch {
      lastError = error as? PlaneAPIError ?? PlaneAPIError.unknown(error)
    }
  }

  func loadWorkItems(project: PlaneProject) async {
    await refreshWorkItems(project: project, stateID: nil, mineOnly: false)
  }

  func refreshWorkItems(project: PlaneProject, stateID: String?, mineOnly: Bool) async {
    guard isConfigured else { return }
    let assigneeID = mineOnly ? currentUser?.id : nil
    let key = workItemsKey(projectID: project.id, stateID: stateID, assigneeID: assigneeID)
    workItemsByProject[project.id] = []
    workItemsMetaByKey[key] = WorkItemsMeta(offset: 0, pageSize: 50, hasMore: true, isLoading: false)
    await loadMoreWorkItems(project: project, stateID: stateID, mineOnly: mineOnly)
  }

  func loadMoreWorkItems(project: PlaneProject, stateID: String?, mineOnly: Bool) async {
    guard isConfigured else { return }
    let assigneeID = mineOnly ? currentUser?.id : nil
    let key = workItemsKey(projectID: project.id, stateID: stateID, assigneeID: assigneeID)
    var meta = workItemsMetaByKey[key] ?? WorkItemsMeta()
    guard !meta.isLoading, meta.hasMore else { return }
    meta.isLoading = true
    workItemsMetaByKey[key] = meta
    do {
      lastError = nil
      let (api, profile) = try apiClient()
      let offset = meta.offset
      let pageSize = meta.pageSize
      let items = try await api.listWorkItems(
        workspaceSlug: profile.workspaceSlug,
        projectID: project.id,
        filter: .init(stateID: stateID, assigneeID: assigneeID, search: nil, limit: pageSize, offset: offset)
      )
      var current = workItemsByProject[project.id] ?? []
      current.append(contentsOf: items)
      workItemsByProject[project.id] = current

      meta.offset = current.count
      meta.hasMore = items.count == pageSize
      meta.isLoading = false
      workItemsMetaByKey[key] = meta
      cache.saveWorkItems(current, profileID: profile.id, projectID: project.id, filterKey: key)
      lastRefreshedByKey[key] = Date()
    } catch {
      var meta = workItemsMetaByKey[key] ?? WorkItemsMeta()
      meta.isLoading = false
      workItemsMetaByKey[key] = meta
      lastError = error as? PlaneAPIError ?? PlaneAPIError.unknown(error)
    }
  }

  func loadStates(project: PlaneProject) async {
    guard isConfigured else { return }
    guard !loadingStates.contains(project.id) else { return }
    loadingStates.insert(project.id)
    defer { loadingStates.remove(project.id) }
    do {
      lastError = nil
      let (api, profile) = try apiClient()
      let states = try await api.listStates(workspaceSlug: profile.workspaceSlug, projectID: project.id)
      statesByProject[project.id] = states
      cache.saveStates(states, profileID: profile.id, projectID: project.id)
      lastRefreshedByKey["states|\(project.id)"] = Date()
    } catch {
      lastError = error as? PlaneAPIError ?? PlaneAPIError.unknown(error)
    }
  }

  func loadLabels(project: PlaneProject) async {
    guard isConfigured else { return }
    guard !loadingLabels.contains(project.id) else { return }
    loadingLabels.insert(project.id)
    defer { loadingLabels.remove(project.id) }
    do {
      lastError = nil
      let (api, profile) = try apiClient()
      let labels = try await api.listLabels(workspaceSlug: profile.workspaceSlug, projectID: project.id)
      labelsByProject[project.id] = labels
      cache.saveLabels(labels, profileID: profile.id, projectID: project.id)
      lastRefreshedByKey["labels|\(project.id)"] = Date()
    } catch {
      lastError = error as? PlaneAPIError ?? PlaneAPIError.unknown(error)
    }
  }

  func loadWorkItemTypes(project: PlaneProject) async {
    guard isConfigured else { return }
    guard !loadingTypes.contains(project.id) else { return }
    loadingTypes.insert(project.id)
    defer { loadingTypes.remove(project.id) }
    do {
      lastError = nil
      let (api, profile) = try apiClient()
      let types = try await api.listWorkItemTypes(workspaceSlug: profile.workspaceSlug, projectID: project.id)
      workItemTypesByProject[project.id] = types
      cache.saveWorkItemTypes(types, profileID: profile.id, projectID: project.id)
      lastRefreshedByKey["types|\(project.id)"] = Date()
    } catch {
      lastError = error as? PlaneAPIError ?? PlaneAPIError.unknown(error)
    }
  }

  func loadMembers() async {
    guard isConfigured else { return }
    do {
      let (api, profile) = try apiClient()
      guard !loadingMembers.contains(profile.workspaceSlug) else { return }
      loadingMembers.insert(profile.workspaceSlug)
      defer { loadingMembers.remove(profile.workspaceSlug) }
      lastError = nil
      let members = try await api.listMembers(workspaceSlug: profile.workspaceSlug)
      membersByWorkspace[profile.workspaceSlug] = members
      cache.saveMembers(members, profileID: profile.id, workspaceSlug: profile.workspaceSlug)
      lastRefreshedByKey["members|\(profile.workspaceSlug)"] = Date()
    } catch {
      lastError = error as? PlaneAPIError ?? PlaneAPIError.unknown(error)
    }
  }

  func workItem(projectID: String, itemID: String) -> PlaneWorkItem? {
    workItemsByProject[projectID]?.first(where: { $0.id == itemID })
  }

  func createWorkItem(project: PlaneProject, body: CreateWorkItemRequest) async throws -> PlaneWorkItem {
    guard isConfigured else { throw PlaneAPIError.invalidResponse }
    let (api, profile) = try apiClient()
    let request = CreateWorkItemRequest(
      name: body.name,
      descriptionHTML: body.descriptionHTML,
      state: body.state,
      priority: body.priority,
      assignees: body.assignees,
      labels: body.labels,
      type: body.type,
      startDate: body.startDate,
      targetDate: body.targetDate
    )
    let created = try await api.createWorkItem(workspaceSlug: profile.workspaceSlug, projectID: project.id, body: request)
    cache.invalidateWorkItems(profileID: profile.id, projectID: project.id)
    return created
  }

  func updateWorkItem(project: PlaneProject, workItemID: String, body: UpdateWorkItemRequest) async throws -> PlaneWorkItem {
    guard isConfigured else { throw PlaneAPIError.invalidResponse }
    let (api, profile) = try apiClient()
    let updated = try await api.updateWorkItem(workspaceSlug: profile.workspaceSlug, projectID: project.id, workItemID: workItemID, body: body)
    if var current = workItemsByProject[project.id], let index = current.firstIndex(where: { $0.id == updated.id }) {
      current[index] = updated
      workItemsByProject[project.id] = current
    }
    cache.invalidateWorkItems(profileID: profile.id, projectID: project.id)
    return updated
  }

  func fetchWorkItemDetail(project: PlaneProject, workItemID: String) async throws -> PlaneWorkItem {
    let (api, profile) = try apiClient()
    return try await api.getWorkItemDetail(
      workspaceSlug: profile.workspaceSlug,
      projectID: project.id,
      workItemID: workItemID
    )
  }

  func searchWorkItems(query: String, project: PlaneProject?) async throws -> [PlaneWorkItem] {
    let (api, profile) = try apiClient()
    return try await api.searchWorkItems(workspaceSlug: profile.workspaceSlug, search: query, projectID: project?.id)
  }

  func loadMyWork(assigneeID: String, perProjectLimit: Int) async throws -> [MyWorkItem] {
    let (api, profile) = try apiClient()
    // No dedicated "assigned to me" workspace endpoint in the provided docs; do per-project fetch with `assignee`.
    // Throttle concurrency to avoid rate limiting.
    let projects = self.projects
    if projects.isEmpty {
      _ = try await api.listProjects(workspaceSlug: profile.workspaceSlug)
    }

    let semaphore = AsyncSemaphore(value: 4)
    var results: [MyWorkItem] = []
    try await withThrowingTaskGroup(of: [MyWorkItem].self) { group in
      for project in projects {
        group.addTask {
          await semaphore.wait()
          defer { Task { await semaphore.signal() } }
          let items = try await api.listWorkItems(
            workspaceSlug: profile.workspaceSlug,
            projectID: project.id,
            filter: .init(stateID: nil, assigneeID: assigneeID, search: nil, limit: perProjectLimit, offset: 0)
          )
          return items.map { MyWorkItem(projectID: project.id, workItem: $0) }
        }
      }

      for try await batch in group {
        results.append(contentsOf: batch)
      }
    }

    // Sort by updated time if present, otherwise stable.
    results.sort { (a, b) in
      (a.workItem.updatedAt ?? a.workItem.createdAt ?? .distantPast) > (b.workItem.updatedAt ?? b.workItem.createdAt ?? .distantPast)
    }
    return results
  }

  private func hydrateFromCache() {
    guard let selectedID = profiles.selectedProfileID else { return }
    if let cached = cache.loadProjects(profileID: selectedID, maxAge: CacheTTL.projects) {
      projects = cached.value
      selectedProject = cached.value.first
      lastRefreshedByKey["projects"] = cached.savedAt
    }
    // Per-project caches are loaded on demand when navigating.
  }

  func hydrateProjectCaches(project: PlaneProject) {
    guard let selectedID = profiles.selectedProfileID else { return }
    if statesByProject[project.id] == nil, let cached = cache.loadStates(profileID: selectedID, projectID: project.id, maxAge: CacheTTL.staticData) {
      statesByProject[project.id] = cached.value
      lastRefreshedByKey["states|\(project.id)"] = cached.savedAt
    }
    if labelsByProject[project.id] == nil, let cached = cache.loadLabels(profileID: selectedID, projectID: project.id, maxAge: CacheTTL.staticData) {
      labelsByProject[project.id] = cached.value
      lastRefreshedByKey["labels|\(project.id)"] = cached.savedAt
    }
    if workItemTypesByProject[project.id] == nil, let cached = cache.loadWorkItemTypes(profileID: selectedID, projectID: project.id, maxAge: CacheTTL.staticData) {
      workItemTypesByProject[project.id] = cached.value
      lastRefreshedByKey["types|\(project.id)"] = cached.savedAt
    }
    let allKey = workItemsKey(projectID: project.id, stateID: nil, assigneeID: nil)
    if workItemsByProject[project.id] == nil,
       let cached = cache.loadWorkItems(profileID: selectedID, projectID: project.id, filterKey: allKey, maxAge: CacheTTL.workItems) {
      workItemsByProject[project.id] = cached.value
      lastRefreshedByKey[allKey] = cached.savedAt
    }
  }

  private func workItemsKey(projectID: String, stateID: String?, assigneeID: String?) -> String {
    let s = stateID ?? ""
    let a = assigneeID ?? ""
    return "workItems|project=\(projectID)|state=\(s)|assignee=\(a)"
  }
}

struct WorkItemsMeta: Hashable {
  var offset: Int = 0
  var pageSize: Int = 50
  var hasMore: Bool = true
  var isLoading: Bool = false
}

enum CacheTTL {
  static let projects: TimeInterval = 30 * 60
  static let workItems: TimeInterval = 5 * 60
  static let staticData: TimeInterval = 24 * 60 * 60
}


actor AsyncSemaphore {
  private var value: Int
  private var waiters: [CheckedContinuation<Void, Never>] = []

  init(value: Int) {
    self.value = value
  }

  func wait() async {
    if value > 0 {
      value -= 1
      return
    }
    await withCheckedContinuation { cont in
      waiters.append(cont)
    }
  }

  func signal() async {
    if let first = waiters.first {
      waiters.removeFirst()
      first.resume()
    } else {
      value += 1
    }
  }
}
