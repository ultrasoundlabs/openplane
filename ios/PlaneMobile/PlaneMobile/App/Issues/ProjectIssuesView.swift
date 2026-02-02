import SwiftUI

struct ProjectIssuesView: View {
  @EnvironmentObject private var session: SessionStore
  let project: PlaneProject

  @State private var isPresentingCreate = false

  var body: some View {
    Group {
      if session.isLoadingWorkItems(for: project.id) && session.workItemsByProject[project.id]?.isEmpty != false {
        ProgressView("Loading work items…")
      } else if let error = session.lastError, (session.workItemsByProject[project.id] ?? []).isEmpty {
        ErrorStateView(title: "Couldn’t load work items", message: error.userFacingMessage) {
          Task { await session.loadWorkItems(project: project) }
        }
      } else {
        List(workItems) { item in
          NavigationLink(value: item) {
            WorkItemRow(item: item, projectIdentifier: project.identifier)
          }
        }
        .navigationDestination(for: PlaneWorkItem.self) { item in
          WorkItemDetailView(project: project, itemID: item.id)
        }
        .refreshable { await session.loadWorkItems(project: project) }
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
      if session.workItemsByProject[project.id] == nil {
        await session.loadWorkItems(project: project)
      }
    }
  }

  private var workItems: [PlaneWorkItem] {
    session.workItemsByProject[project.id] ?? []
  }
}

