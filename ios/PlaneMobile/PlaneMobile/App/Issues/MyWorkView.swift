import SwiftUI

struct MyWorkView: View {
  @EnvironmentObject private var session: SessionStore

  @State private var isLoading = false
  @State private var errorMessage: String?

  @State private var items: [MyWorkItem] = []
  @State private var groupByProject = true

  var body: some View {
    Group {
      if !session.isConfigured {
        ContentUnavailableView("Not configured", systemImage: "gear", description: Text("Add a Plane profile in Settings."))
      } else if session.currentUser == nil {
        ProgressView("Loading user…")
      } else if isLoading && items.isEmpty {
        ProgressView("Loading my work…")
      } else if let errorMessage, items.isEmpty {
        ErrorStateView(title: "Couldn’t load my work", message: errorMessage) {
          Task { await load() }
        }
      } else if items.isEmpty {
        ContentUnavailableView("Nothing assigned", systemImage: "checkmark.circle", description: Text("No work items are currently assigned to you."))
      } else {
        List {
          if groupByProject {
            ForEach(groupedKeys, id: \.self) { projectID in
              if let group = grouped[projectID], let project = session.projects.first(where: { $0.id == projectID }) {
                Section(project.name) {
                  ForEach(group) { item in
                    NavigationLink {
                      WorkItemDetailView(project: project, itemID: item.workItem.id)
                    } label: {
                      WorkItemRow(item: item.workItem, projectIdentifier: project.identifier)
                    }
                  }
                }
              }
            }
          } else {
            ForEach(items) { item in
              if let project = session.projects.first(where: { $0.id == item.projectID }) {
                NavigationLink {
                  WorkItemDetailView(project: project, itemID: item.workItem.id)
                } label: {
                  WorkItemRow(item: item.workItem, projectIdentifier: project.identifier)
                }
              }
            }
          }
        }
        .refreshable { await load() }
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          Task { await load() }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Toggle("Group by project", isOn: $groupByProject)
        } label: {
          Image(systemName: "line.3.horizontal.decrease.circle")
        }
      }
    }
    .task {
      if session.currentUser == nil {
        await session.bootstrap()
      }
      if items.isEmpty {
        await load()
      }
    }
  }

  private func load() async {
    guard let userID = session.currentUser?.id else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      errorMessage = nil
      let results = try await session.loadMyWork(assigneeID: userID, perProjectLimit: 30)
      items = results
    } catch {
      let apiError = error as? PlaneAPIError ?? .unknown(error)
      errorMessage = apiError.userFacingMessage
    }
  }

  private var grouped: [String: [MyWorkItem]] {
    Dictionary(grouping: items, by: \.projectID)
  }

  private var groupedKeys: [String] {
    grouped.keys.sorted()
  }
}

struct MyWorkItem: Identifiable, Hashable {
  let projectID: String
  let workItem: PlaneWorkItem
  var id: String { "\(projectID)|\(workItem.id)" }
}

