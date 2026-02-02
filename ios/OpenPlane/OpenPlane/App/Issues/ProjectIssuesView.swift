import SwiftUI

struct ProjectIssuesView: View {
  @EnvironmentObject private var session: SessionStore
  @EnvironmentObject private var preferences: AppPreferences
  @EnvironmentObject private var networkMonitor: NetworkMonitor
  let project: PlaneProject

  @State private var isPresentingCreate = false
  @State private var mineOnly = false
  @State private var selectedStateID: String?
  @State private var searchText: String = ""
  @State private var isSearchLoading = false
  @State private var searchResults: [PlaneWorkItem] = []

  var body: some View {
    Group {
      if isSearchMode {
        List(searchResults) { item in
          NavigationLink(value: item) {
            WorkItemRow(item: item, projectIdentifier: project.identifier)
          }
        }
        .overlay {
          if isSearchLoading {
            ProgressView("Searching…")
          } else if searchResults.isEmpty {
            ContentUnavailableView("No results", systemImage: "magnifyingglass", description: Text("Try a different search."))
          }
        }
      } else if isLoadingInitialPage {
        ProgressView("Loading work items…")
      } else if let error = session.lastErrorByKey[sessionWorkItemsKey], (session.workItemsByProject[project.id] ?? []).isEmpty {
        ErrorStateView(title: "Couldn’t load work items", message: error.userFacingMessage) {
          Task { await session.refreshWorkItems(project: project, stateID: selectedStateID, mineOnly: mineOnly, replaceExisting: false) }
        }
      } else {
        List {
          ForEach(workItems) { item in
            NavigationLink(value: item) {
              WorkItemRow(item: item, projectIdentifier: project.identifier)
                .onAppear {
                  if item.id == workItems.last?.id {
                    Task { await session.loadMoreWorkItems(project: project, stateID: selectedStateID, mineOnly: mineOnly) }
                  }
                }
            }
          }

          if session.workItemsMeta(forKey: sessionWorkItemsKey).isLoading || session.workItemsMeta(forKey: sessionWorkItemsKey).isRefreshing {
            HStack { Spacer(); ProgressView(); Spacer() }
          } else if session.workItemsMeta(forKey: sessionWorkItemsKey).hasMore, hasLoadedOnceForKey {
            HStack {
              Spacer()
              Button("Load more") {
                Task { await session.loadMoreWorkItems(project: project, stateID: selectedStateID, mineOnly: mineOnly) }
              }
              Spacer()
            }
          }

          if let lastRefreshedText {
            HStack {
              Spacer()
              Text(lastRefreshedText)
                .font(.footnote)
                .foregroundStyle(.secondary)
              Spacer()
            }
          }
        }
        .navigationDestination(for: PlaneWorkItem.self) { item in
          WorkItemDetailView(project: project, itemID: item.id)
        }
        .refreshable { await session.refreshWorkItems(project: project, stateID: selectedStateID, mineOnly: mineOnly, replaceExisting: false) }
      }
    }
    .navigationTitle(project.name)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          isPresentingCreate = true
        } label: {
          Image(systemName: "plus")
        }
      }
      ToolbarItem(placement: .topBarLeading) {
        Menu {
          Toggle("Mine only", isOn: $mineOnly)

          Picker("State", selection: $selectedStateID) {
            Text("All states").tag(Optional<String>.none)
            ForEach(session.statesByProject[project.id] ?? []) { state in
              Text(state.name).tag(Optional(state.id))
            }
          }
        } label: {
          Image(systemName: "line.3.horizontal.decrease.circle")
        }
      }
    }
    .sheet(isPresented: $isPresentingCreate) {
      NavigationStack {
        CreateWorkItemView(project: project) {
          isPresentingCreate = false
        }
        .environmentObject(session)
      }
    }
    .task(id: project.id) {
      session.selectedProject = project
      session.hydrateProjectCaches(project: project)
      if session.statesByProject[project.id] == nil { await session.loadStates(project: project) }

      await autoLoadIfNeeded()
    }
    .task(id: autoRefreshTaskID) {
      guard preferences.autoRefreshEnabled else { return }
      while !Task.isCancelled {
        let interval = max(30, preferences.autoRefreshIntervalSeconds)
        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        guard !Task.isCancelled else { return }
        guard networkMonitor.isOnline else { continue }
        guard !isSearchMode else { continue }
        // Avoid stacking refreshes.
        if session.workItemsMeta(forKey: sessionWorkItemsKey).isLoading { continue }
        await session.refreshWorkItems(project: project, stateID: selectedStateID, mineOnly: mineOnly, replaceExisting: false)
      }
    }
    .searchable(text: $searchText, prompt: "Search work items")
    .onChange(of: searchText) { _, newValue in
      Task { await runSearch(query: newValue) }
    }
    .onChange(of: mineOnly) { _, _ in
      Task { await session.refreshWorkItems(project: project, stateID: selectedStateID, mineOnly: mineOnly, replaceExisting: true) }
    }
    .onChange(of: selectedStateID) { _, _ in
      Task { await session.refreshWorkItems(project: project, stateID: selectedStateID, mineOnly: mineOnly, replaceExisting: true) }
    }
  }

  private var workItems: [PlaneWorkItem] {
    session.workItemsByKey[sessionWorkItemsKey] ?? []
  }

  private var sessionWorkItemsKey: String {
    let assigneeID = mineOnly ? session.currentUser?.id : nil
    let s = selectedStateID ?? ""
    let a = assigneeID ?? ""
    return "workItems|project=\(project.id)|state=\(s)|assignee=\(a)"
  }

  private func runSearch(query: String) async {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      isSearchLoading = false
      searchResults = []
      return
    }
    isSearchLoading = true
    do {
      searchResults = try await session.searchWorkItems(query: trimmed, project: project)
    } catch {
      searchResults = []
    }
    isSearchLoading = false
  }

  private var isSearchMode: Bool {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
  }

  private var isLoadingInitialPage: Bool {
    let meta = session.workItemsMeta(forKey: sessionWorkItemsKey)
    let hasItems = (session.workItemsByProject[project.id] ?? []).isEmpty == false
    return !hasItems && (meta.isLoading || meta.isRefreshing || session.isLoadingWorkItems(for: project.id))
  }

  private var lastRefreshedText: String? {
    guard let date = session.lastRefreshed(forKey: sessionWorkItemsKey) else { return nil }
    return "Updated \(date.formatted(.relative(presentation: .named)))"
  }

  private var hasLoadedOnceForKey: Bool {
    session.lastRefreshed(forKey: sessionWorkItemsKey) != nil
  }

  private func autoLoadIfNeeded() async {
    let hasData = (session.workItemsByProject[project.id] ?? []).isEmpty == false
    if !hasData {
      await session.refreshWorkItems(project: project, stateID: selectedStateID, mineOnly: mineOnly, replaceExisting: true)
      return
    }

    // Stale-while-revalidate: keep cached items visible, refresh in background.
    if let last = session.lastRefreshed(forKey: sessionWorkItemsKey),
       Date().timeIntervalSince(last) >= CacheTTL.workItems {
      await session.refreshWorkItems(project: project, stateID: selectedStateID, mineOnly: mineOnly, replaceExisting: false)
    }
  }

  private var autoRefreshTaskID: String {
    // Restart the loop when the project or filter changes.
    "\(project.id)|\(selectedStateID ?? "")|\(mineOnly ? "mine" : "all")"
  }
}
