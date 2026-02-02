import SwiftUI

struct ProjectIssuesView: View {
  @EnvironmentObject private var session: SessionStore
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
      } else if session.isLoadingWorkItems(for: project.id) && session.workItemsByProject[project.id]?.isEmpty != false {
        ProgressView("Loading work items…")
      } else if let error = session.lastError, (session.workItemsByProject[project.id] ?? []).isEmpty {
        ErrorStateView(title: "Couldn’t load work items", message: error.userFacingMessage) {
          Task { await session.refreshWorkItems(project: project, stateID: selectedStateID, mineOnly: mineOnly) }
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

          if session.workItemsMeta(forKey: sessionWorkItemsKey).isLoading {
            HStack { Spacer(); ProgressView(); Spacer() }
          } else if session.workItemsMeta(forKey: sessionWorkItemsKey).hasMore {
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
        .refreshable { await session.refreshWorkItems(project: project, stateID: selectedStateID, mineOnly: mineOnly) }
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
    .task {
      session.selectedProject = project
      session.hydrateProjectCaches(project: project)
      if session.statesByProject[project.id] == nil { await session.loadStates(project: project) }
      if session.labelsByProject[project.id] == nil { await session.loadLabels(project: project) }
      if session.workItemTypesByProject[project.id] == nil { await session.loadWorkItemTypes(project: project) }

      if session.workItemsByProject[project.id] == nil || session.workItemsByProject[project.id]?.isEmpty == true {
        await session.refreshWorkItems(project: project, stateID: selectedStateID, mineOnly: mineOnly)
      }
    }
    .searchable(text: $searchText, prompt: "Search work items")
    .onChange(of: searchText) { _, newValue in
      Task { await runSearch(query: newValue) }
    }
    .onChange(of: mineOnly) { _, _ in
      Task { await session.refreshWorkItems(project: project, stateID: selectedStateID, mineOnly: mineOnly) }
    }
    .onChange(of: selectedStateID) { _, _ in
      Task { await session.refreshWorkItems(project: project, stateID: selectedStateID, mineOnly: mineOnly) }
    }
  }

  private var workItems: [PlaneWorkItem] {
    session.workItemsByProject[project.id] ?? []
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

  private var lastRefreshedText: String? {
    guard let date = session.lastRefreshed(forKey: sessionWorkItemsKey) else { return nil }
    return "Updated \(date.formatted(.relative(presentation: .named)))"
  }
}
