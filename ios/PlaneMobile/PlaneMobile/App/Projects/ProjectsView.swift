import SwiftUI

struct ProjectsView: View {
  @EnvironmentObject private var session: SessionStore

  var body: some View {
    Group {
      if !session.isConfigured {
        ContentUnavailableView("Not configured", systemImage: "gear", description: Text("Set your Plane base URL, workspace slug, and API key."))
      } else if session.isLoadingProjects && session.projects.isEmpty {
        ProgressView("Loading projects…")
      } else if let error = session.lastError, session.projects.isEmpty {
        ErrorStateView(title: "Couldn’t load projects", message: error.userFacingMessage) {
          Task { await session.loadProjects() }
        }
      } else if session.projects.isEmpty {
        ContentUnavailableView("No projects found", systemImage: "square.grid.2x2")
      } else {
        List(session.projects) { project in
          NavigationLink(value: project) {
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Text(project.name)
                  .font(.headline)
                Spacer()
                Text(project.identifier)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              if let description = project.description, !description.isEmpty {
                Text(description)
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
                  .lineLimit(2)
              }
            }
          }
        }
        .navigationDestination(for: PlaneProject.self) { project in
          ProjectIssuesView(project: project)
        }
        .refreshable { await session.loadProjects() }
      }
    }
    .navigationTitle("Projects")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          Task { await session.loadProjects() }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
      }
    }
    .task {
      if session.projects.isEmpty {
        await session.loadProjects()
      }
    }
  }
}

