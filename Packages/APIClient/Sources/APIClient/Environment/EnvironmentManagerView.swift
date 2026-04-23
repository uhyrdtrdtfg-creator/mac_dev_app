import SwiftUI
import SwiftData

/// View for managing environments (Dev, Staging, Prod, etc.)
public struct EnvironmentManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \EnvironmentModel.name) private var environments: [EnvironmentModel]

    @State private var showAddEnvironment = false
    @State private var newEnvName = ""
    @State private var selectedEnvironment: EnvironmentModel?
    @State private var editingVariables: [(key: String, value: String, id: UUID)] = []

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Title bar with close button
            HStack {
                Text("Environment Manager")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(12)
            .background(.bar)

            Divider()

            HSplitView {
                // Environment list
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Environments")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            showAddEnvironment = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)

                    Divider()

                List(selection: $selectedEnvironment) {
                    ForEach(environments) { env in
                        HStack {
                            if env.isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                            Text(env.name)
                            Spacer()
                            Text("\(env.variables.count) vars")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(env)
                        .contextMenu {
                            Button("Set Active") {
                                setActiveEnvironment(env)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                deleteEnvironment(env)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 180, maxWidth: 250)

            // Environment details
            VStack(alignment: .leading, spacing: 0) {
                if let env = selectedEnvironment {
                    HStack {
                        Text(env.name)
                            .font(.headline)

                        if env.isActive {
                            Text("Active")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }

                        Spacer()

                        Button("Set Active") {
                            setActiveEnvironment(env)
                        }
                        .buttonStyle(.bordered)
                        .disabled(env.isActive)
                    }
                    .padding(8)

                    Divider()

                    // Variables editor
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Variables")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Button {
                                editingVariables.append((key: "", value: "", id: UUID()))
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)

                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach($editingVariables, id: \.id) { $item in
                                    HStack(spacing: 4) {
                                        TextField("Key", text: $item.key)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(maxWidth: .infinity)

                                        TextField("Value", text: $item.value)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(maxWidth: .infinity)

                                        Button {
                                            editingVariables.removeAll { $0.id == item.id }
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(8)
                        }

                        HStack {
                            Spacer()
                            Button("Save") {
                                saveVariables(to: env)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(8)
                    }
                } else {
                    ContentUnavailableView(
                        "No Environment Selected",
                        systemImage: "globe",
                        description: Text("Select an environment to view and edit its variables")
                    )
                }
            }
            .frame(minWidth: 300)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $showAddEnvironment) {
            VStack(spacing: 16) {
                Text("New Environment")
                    .font(.headline)

                TextField("Name (e.g., Development, Staging, Production)", text: $newEnvName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)

                HStack {
                    Button("Cancel") {
                        newEnvName = ""
                        showAddEnvironment = false
                    }
                    .buttonStyle(.bordered)

                    Button("Create") {
                        createEnvironment()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newEnvName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(20)
        }
        .onChange(of: selectedEnvironment) { _, newEnv in
            loadVariables(from: newEnv)
        }
        .onAppear {
            if selectedEnvironment == nil, let first = environments.first {
                selectedEnvironment = first
            }
        }
    }

    private func createEnvironment() {
        let env = EnvironmentModel(name: newEnvName.trimmingCharacters(in: .whitespaces))
        modelContext.insert(env)
        newEnvName = ""
        showAddEnvironment = false
        selectedEnvironment = env
    }

    private func deleteEnvironment(_ env: EnvironmentModel) {
        if selectedEnvironment == env {
            selectedEnvironment = nil
        }
        modelContext.delete(env)
    }

    private func setActiveEnvironment(_ env: EnvironmentModel) {
        // Deactivate all others
        for e in environments {
            e.isActive = false
        }
        env.isActive = true

        // Update the script engine's environment store
        ScriptEngine.setEnvironment(env.variables)
    }

    private func loadVariables(from env: EnvironmentModel?) {
        guard let env = env else {
            editingVariables = []
            return
        }
        editingVariables = env.variables.map { (key: $0.key, value: $0.value, id: UUID()) }
    }

    private func saveVariables(to env: EnvironmentModel) {
        var vars: [String: String] = [:]
        for item in editingVariables where !item.key.isEmpty {
            vars[item.key] = item.value
        }
        env.variables = vars

        // If this is the active environment, update the script engine
        if env.isActive {
            ScriptEngine.setEnvironment(vars)
        }
    }
}
