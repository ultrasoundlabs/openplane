import SwiftUI

struct IssuesView: View {
  @EnvironmentObject private var session: SessionStore

  enum Mode: String, CaseIterable, Identifiable {
    case project = "Project"
    case myWork = "My Work"
    var id: String { rawValue }
  }

  @State private var mode: Mode = .project

  var body: some View {
    VStack(spacing: 0) {
      Picker("Mode", selection: $mode) {
        ForEach(Mode.allCases) { m in
          Text(m.rawValue).tag(m)
        }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)
      .padding(.top, 8)

      if mode == .project {
        HStack {
          Text("Project")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Spacer()
          Picker("Project", selection: selectedProjectID) {
            Text("Select…").tag(Optional<String>.none)
            ForEach(session.projects) { project in
              Text("\(project.name) (\(project.identifier))").tag(Optional(project.id))
            }
          }
          .pickerStyle(.menu)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
      }

      Group {
        switch mode {
        case .project:
          if !session.isConfigured {
            ContentUnavailableView("Not configured", systemImage: "gear", description: Text("Add a Plane profile in Settings."))
          } else if session.projects.isEmpty {
            ProgressView("Loading projects…")
          } else if let project = session.selectedProject {
            ProjectIssuesView(project: project)
              .id(project.id)
          } else {
            ContentUnavailableView("Select a project", systemImage: "square.grid.2x2", description: Text("Pick a project above to view its work items."))
          }
        case .myWork:
          MyWorkView()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .navigationTitle("Work")
    .task {
      if session.isConfigured, session.projects.isEmpty {
        await session.loadProjects(force: false)
      }
    }
  }

  private var selectedProjectID: Binding<String?> {
    Binding(
      get: { session.selectedProject?.id },
      set: { id in
        session.selectedProject = id.flatMap { pid in
          session.projects.first(where: { $0.id == pid })
        }
      }
    )
  }
}
