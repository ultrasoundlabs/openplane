import SwiftUI

struct ProjectsView: View {
  @EnvironmentObject private var session: SessionStore
  @Environment(\.openURL) private var openURL

  var body: some View {
    Group {
      if !session.isConfigured {
        ContentUnavailableView("Not configured", systemImage: "gear", description: Text("Add a Plane profile in Settings."))
      } else if session.isLoadingProjects && session.projects.isEmpty {
        ProgressView("Loading projects…")
      } else if let error = session.lastError, session.projects.isEmpty {
        ErrorStateView(title: "Couldn’t load projects", message: error.userFacingMessage) {
          Task { await session.loadProjects(force: true) }
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
        .refreshable { await session.loadProjects(force: true) }
      }
    }
    .navigationTitle("Projects")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          Task { await session.loadProjects(force: true) }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        if let profile = session.currentProfile {
          Button {
            let url = profile.webBaseURL.appending(path: "\(profile.workspaceSlug)/projects/")
            openURL(url)
          } label: {
            Image(systemName: "safari")
          }
          .accessibilityLabel("Open Plane in Safari")
        }
      }
    }
    .task {
      await session.loadProjects(force: false)
    }
  }
}
