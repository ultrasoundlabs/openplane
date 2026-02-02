import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var session: SessionStore

  let onSaved: () async -> Void

  @State private var baseURLString: String = ""
  @State private var workspaceSlug: String = ""
  @State private var apiKey: String = ""

  @State private var isSaving = false
  @State private var errorMessage: String?

  var body: some View {
    Form {
      Section("Plane Instance") {
        TextField("Base URL (https://plane.example.com)", text: $baseURLString)
          .textInputAutocapitalization(.never)
          .keyboardType(.URL)
          .autocorrectionDisabled()

        TextField("Workspace slug (e.g. my-team)", text: $workspaceSlug)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
      }

      Section("Authentication") {
        SecureField("Personal Access Token", text: $apiKey)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        Text("Sent as `X-API-Key` on every request.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Section {
        Button {
          Task { await save() }
        } label: {
          if isSaving {
            ProgressView()
          } else {
            Text("Save & Connect")
          }
        }
        .disabled(isSaving)
      }
    }
    .navigationTitle("Settings")
    .onAppear {
      baseURLString = session.configuration.baseURLString
      workspaceSlug = session.configuration.workspaceSlug
      apiKey = session.configuration.apiKey ?? ""
    }
    .alert("Couldn’t save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "")
    }
  }

  private func save() async {
    isSaving = true
    defer { isSaving = false }

    do {
      try session.updateConfiguration(
        baseURLString: baseURLString,
        workspaceSlug: workspaceSlug,
        apiKey: apiKey
      )
      await onSaved()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

