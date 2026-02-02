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

      Group {
        switch mode {
        case .project:
          if session.selectedProject == nil {
            ContentUnavailableView("Pick a project", systemImage: "square.grid.2x2", description: Text("Choose a project from the Projects tab to view its work items here."))
          } else {
            ProjectIssuesView(project: session.selectedProject!)
          }
        case .myWork:
          MyWorkView()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .navigationTitle("Work")
  }
}
