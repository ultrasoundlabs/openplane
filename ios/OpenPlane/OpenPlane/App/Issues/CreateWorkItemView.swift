import SwiftUI

struct CreateWorkItemView: View {
  @EnvironmentObject private var session: SessionStore
  let project: PlaneProject
  let onDone: () -> Void

  @State private var title: String = ""
  @State private var description: String = ""
  @State private var priority: PlanePriority = .none
  @State private var stateID: String?
  @State private var selectedAssigneeIDs: Set<String> = []
  @State private var selectedLabelIDs: Set<String> = []
  @State private var selectedTypeID: String?
  @State private var hasStartDate: Bool = false
  @State private var hasTargetDate: Bool = false
  @State private var startDate: Date? = nil
  @State private var targetDate: Date? = nil

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
        if session.statesByProject[project.id] == nil {
          ProgressView("Loading states…")
        } else {
          Picker("State", selection: $stateID) {
            Text("Unassigned").tag(Optional<String>.none)
            ForEach(session.statesByProject[project.id] ?? []) { s in
              Text(s.name).tag(Optional(s.id))
            }
          }
        }

        Picker("Priority", selection: $priority) {
          ForEach(PlanePriority.allCases, id: \.self) { p in
            Text(p.displayName).tag(p)
          }
        }

        Picker("Type", selection: $selectedTypeID) {
          Text("Unassigned").tag(Optional<String>.none)
          ForEach(session.workItemTypesByProject[project.id] ?? [], id: \.id) { t in
            Text(t.name ?? t.id).tag(Optional(t.id))
          }
        }
      }

      Section("People") {
        NavigationLink {
          MultiSelectListView(
            title: "Assignees",
            items: members,
            selected: $selectedAssigneeIDs
          ) { member in
            (member.id, member.bestName)
          }
        } label: {
          LabeledContent("Assignees") {
            Text(assigneeSummary).foregroundStyle(.secondary)
          }
        }
      }

      Section("Labels") {
        NavigationLink {
          MultiSelectListView(
            title: "Labels",
            items: labels,
            selected: $selectedLabelIDs
          ) { label in
            (label.id, label.name ?? label.id)
          }
        } label: {
          LabeledContent("Labels") {
            Text(labelSummary).foregroundStyle(.secondary)
          }
        }
      }

      Section("Dates") {
        Toggle("Start date", isOn: $hasStartDate)
        if hasStartDate {
          DatePicker("Start", selection: Binding(get: { startDate ?? Date() }, set: { startDate = $0 }), displayedComponents: .date)
        }
        Toggle("Target date", isOn: $hasTargetDate)
        if hasTargetDate {
          DatePicker("Target", selection: Binding(get: { targetDate ?? Date() }, set: { targetDate = $0 }), displayedComponents: .date)
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
    .task {
      session.hydrateProjectCaches(project: project)
      if session.statesByProject[project.id] == nil { await session.loadStates(project: project) }
      if session.labelsByProject[project.id] == nil { await session.loadLabels(project: project) }
      if session.workItemTypesByProject[project.id] == nil { await session.loadWorkItemTypes(project: project) }
      if session.currentUser == nil { await session.bootstrap() }
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
      let body = CreateWorkItemRequest(
        name: title,
        descriptionHTML: description.trimmedNonEmpty.map { PlaneHTML.simpleParagraph($0) },
        state: stateID,
        priority: priority,
        assignees: selectedAssigneeIDs.isEmpty ? nil : Array(selectedAssigneeIDs),
        labels: selectedLabelIDs.isEmpty ? nil : Array(selectedLabelIDs),
        type: selectedTypeID,
        startDate: (hasStartDate ? startDate : nil).map { PlaneDateFormatter.api.string(from: $0) },
        targetDate: (hasTargetDate ? targetDate : nil).map { PlaneDateFormatter.api.string(from: $0) }
      )
      _ = try await session.createWorkItem(project: project, body: body)
      await session.refreshWorkItems(project: project, stateID: nil, mineOnly: false)
      onDone()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private var members: [PlaneMember] {
    guard let slug = session.currentProfile?.workspaceSlug else { return [] }
    return session.membersByWorkspace[slug] ?? []
  }

  private var labels: [PlaneLabel] {
    session.labelsByProject[project.id] ?? []
  }

  private var assigneeSummary: String {
    if selectedAssigneeIDs.isEmpty { return "None" }
    let map = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.bestName) })
    return selectedAssigneeIDs.compactMap { map[$0] }.sorted().joined(separator: ", ")
  }

  private var labelSummary: String {
    if selectedLabelIDs.isEmpty { return "None" }
    let map = Dictionary(uniqueKeysWithValues: labels.map { ($0.id, $0.name ?? $0.id) })
    return selectedLabelIDs.compactMap { map[$0] }.sorted().joined(separator: ", ")
  }
}
