import SwiftUI

struct WorkItemDetailView: View {
  @EnvironmentObject private var session: SessionStore
  let project: PlaneProject
  let itemID: String

  @State private var isLoading = false
  @State private var errorMessage: String?

  @State private var selectedStateID: String?
  @State private var selectedPriority: PlanePriority = .none

  var body: some View {
    Group {
      if let item = session.workItem(projectID: project.id, itemID: itemID) {
        Form {
          Section {
            Text(item.name ?? "Untitled")
              .font(.headline)
            if let identifier = item.identifier {
              Text(identifier)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          Section("Status") {
            if session.statesByProject[project.id] == nil {
              ProgressView("Loading states…")
            } else {
              Picker("State", selection: Binding(get: { selectedStateID ?? item.stateID }, set: { selectedStateID = $0 })) {
                Text("Unassigned").tag(Optional<String>.none)
                ForEach(session.statesByProject[project.id] ?? []) { state in
                  Text(state.name).tag(Optional(state.id))
                }
              }
            }

            Picker("Priority", selection: $selectedPriority) {
              ForEach(PlanePriority.allCases, id: \.self) { p in
                Text(p.displayName).tag(p)
              }
            }

            Button("Save changes") {
              Task { await saveUpdates() }
            }
            .disabled(isLoading)
          }

          if let description = item.descriptionText?.trimmedNonEmpty {
            Section("Description") {
              Text(description)
            }
          }
        }
      } else {
        ProgressView("Loading…")
          .task { await load() }
      }
    }
    .navigationTitle("Work item")
    .navigationBarTitleDisplayMode(.inline)
    .alert("Update failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "")
    }
    .task {
      selectedPriority = session.workItem(projectID: project.id, itemID: itemID)?.priority ?? .none
      if session.statesByProject[project.id] == nil {
        await session.loadStates(project: project)
      }
    }
  }

  private func load() async {
    await session.loadWorkItems(project: project)
  }

  private func saveUpdates() async {
    isLoading = true
    defer { isLoading = false }
    do {
      try await session.updateWorkItem(
        project: project,
        workItemID: itemID,
        stateID: selectedStateID,
        priority: selectedPriority
      )
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

