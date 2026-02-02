import SwiftUI

struct IssuesView: View {
  @EnvironmentObject private var session: SessionStore

  var body: some View {
    Group {
      if session.selectedProject == nil {
        ContentUnavailableView("Pick a project", systemImage: "square.grid.2x2", description: Text("Choose a project from the Projects tab to view its work items here."))
      } else {
        ProjectIssuesView(project: session.selectedProject!)
      }
    }
    .navigationTitle("Work")
  }
}

