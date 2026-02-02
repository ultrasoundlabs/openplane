import SwiftUI

struct CreateWorkItemView: View {
  @EnvironmentObject private var session: SessionStore
  let project: PlaneProject
  let onDone: () -> Void

  @State private var title: String = ""
  @State private var description: String = ""
  @State private var priority: PlanePriority = .none

  @State private var isCreating = false
  @State private var errorMessage: String?

  var body: some View {
    Form {
      Section("Title") {
        TextField("Work item title", text: $title)
      }

      Section("Description") {
        TextEditor(text: $description)
          .frame(minHeight: 120)
      }

      Section("Details") {
        Picker("Priority", selection: $priority) {
          ForEach(PlanePriority.allCases, id: \.self) { p in
            Text(p.displayName).tag(p)
          }
        }
      }

      Section {
        Button {
          Task { await create() }
        } label: {
          if isCreating {
            ProgressView()
          } else {
            Text("Create")
          }
        }
        .disabled(isCreating || title.trimmedNonEmpty == nil)
      }
    }
    .navigationTitle("New work item")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") { onDone() }
      }
    }
    .alert("Create failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "")
    }
  }

  private func create() async {
    isCreating = true
    defer { isCreating = false }
    do {
      _ = try await session.createWorkItem(
        project: project,
        name: title,
        descriptionText: description.trimmedNonEmpty,
        priority: priority
      )
      await session.loadWorkItems(project: project)
      onDone()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

