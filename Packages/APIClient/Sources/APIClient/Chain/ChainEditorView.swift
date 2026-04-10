import SwiftUI
import SwiftData

struct ChainEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var chain: ChainModel

    @Query(sort: \SavedRequestModel.updatedAt, order: .reverse)
    private var allSavedRequests: [SavedRequestModel]

    @State private var runResult = ChainRunResult()
    @State private var showAddStep = false
    @State private var addStepSearch = ""
    @State private var expandedStepId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                TextField("Chain Name", text: $chain.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.headline)
                    .onChange(of: chain.name) { chain.updatedAt = Date() }

                Spacer()

                if case .running = runResult.status {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.trailing, 4)
                }

                Button {
                    Task { await executeChain() }
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(chain.steps.isEmpty || {
                    if case .running = runResult.status { return true }
                    return false
                }())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Steps section
                    stepsSection

                    Divider()
                        .padding(.vertical, 8)

                    // Results section
                    resultsSection
                }
                .padding(12)
            }
        }
    }

    // MARK: - Steps Section

    @ViewBuilder
    private var stepsSection: some View {
        Text("Steps")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)

        ForEach(chain.sortedSteps) { step in
            stepRow(step)
        }

        Button {
            showAddStep = true
        } label: {
            Label("Add Step", systemImage: "plus")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .padding(.top, 6)
        .popover(isPresented: $showAddStep) {
            addStepPopover
        }
    }

    private func stepRow(_ step: ChainStepModel) -> some View {
        let savedRequest = allSavedRequests.first { $0.id == step.savedRequestId }
        let methodStr = savedRequest?.method ?? "?"
        let urlStr = savedRequest?.url ?? "(deleted)"
        let nameStr = savedRequest?.name ?? "(deleted)"

        return HStack(spacing: 8) {
            Text("\(step.order + 1).")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)

            Text(methodStr)
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(methodColor(methodStr))
                .frame(width: 50, alignment: .leading)

            Text(nameStr)
                .font(.caption)
                .lineLimit(1)

            Text(urlStr)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button { moveStep(step, direction: -1) } label: {
                Image(systemName: "chevron.up")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
            .disabled(step.order == 0)

            Button { moveStep(step, direction: 1) } label: {
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
            .disabled(step.order == chain.steps.count - 1)

            Button { removeStep(step) } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
        .padding(.vertical, 1)
    }

    // MARK: - Add Step Popover

    private var addStepPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Request").font(.headline)
            TextField("Search...", text: $addStepSearch)
                .textFieldStyle(.roundedBorder)

            let filtered = allSavedRequests.filter { req in
                addStepSearch.isEmpty ||
                req.name.localizedCaseInsensitiveContains(addStepSearch) ||
                req.url.localizedCaseInsensitiveContains(addStepSearch)
            }

            List(filtered) { req in
                Button {
                    addStep(savedRequestId: req.id)
                    showAddStep = false
                    addStepSearch = ""
                } label: {
                    HStack {
                        Text(req.method)
                            .font(.caption.weight(.bold).monospaced())
                            .foregroundStyle(methodColor(req.method))
                            .frame(width: 50, alignment: .leading)
                        Text(req.name)
                            .font(.caption)
                        Spacer()
                        Text(req.url)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .frame(minHeight: 200)
        }
        .padding()
        .frame(width: 450, height: 350)
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        if runResult.stepResults.isEmpty && runResult.status == .idle {
            Text("Run the chain to see results")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack {
                Text("Results")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let elapsed = totalDuration {
                    Text(String(format: "%.0fms", elapsed * 1000))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 4)

            ForEach(runResult.stepResults) { stepResult in
                resultRow(stepResult)
            }

            if case .running(let currentStep) = runResult.status {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Running step \(currentStep + 1)...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func resultRow(_ stepResult: StepResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedStepId = expandedStepId == stepResult.id ? nil : stepResult.id
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: stepResult.error == nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(stepResult.error == nil ? .green : .red)
                        .font(.caption)

                    Text("\(stepResult.stepOrder + 1).")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Text(stepResult.requestMethod)
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(methodColor(stepResult.requestMethod))

                    Text(stepResult.requestName)
                        .font(.caption)
                        .lineLimit(1)

                    Spacer()

                    if let status = stepResult.responseStatus {
                        Text("\(status)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(statusColor(status))
                    }

                    if let duration = stepResult.duration {
                        Text(String(format: "%.0fms", duration * 1000))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: expandedStepId == stepResult.id ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            if let error = stepResult.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 24)
                    .padding(.bottom, 4)
            }

            if expandedStepId == stepResult.id {
                expandedDetail(stepResult)
            }
        }
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.3)))
        .padding(.vertical, 1)
    }

    private func expandedDetail(_ stepResult: StepResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("URL: \(stepResult.requestURL)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let resp = stepResult.httpResponse {
                Text("Response Body:")
                    .font(.caption.weight(.semibold))
                let bodyStr = String(data: resp.body, encoding: .utf8) ?? "(binary)"
                ScrollView {
                    Text(bodyStr)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 4).fill(.background))
            }

            if !stepResult.consoleLogs.isEmpty {
                Text("Console:")
                    .font(.caption.weight(.semibold))
                Text(stepResult.consoleLogs)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.leading, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func addStep(savedRequestId: UUID) {
        let newOrder = chain.steps.count
        let step = ChainStepModel(order: newOrder, savedRequestId: savedRequestId)
        step.chain = chain
        chain.steps.append(step)
        chain.updatedAt = Date()
    }

    private func removeStep(_ step: ChainStepModel) {
        chain.steps.removeAll { $0.id == step.id }
        modelContext.delete(step)
        // Re-order remaining steps
        for (index, s) in chain.sortedSteps.enumerated() {
            s.order = index
        }
        chain.updatedAt = Date()
    }

    private func moveStep(_ step: ChainStepModel, direction: Int) {
        let sorted = chain.sortedSteps
        guard let currentIndex = sorted.firstIndex(where: { $0.id == step.id }) else { return }
        let targetIndex = currentIndex + direction
        guard targetIndex >= 0 && targetIndex < sorted.count else { return }

        sorted[currentIndex].order = targetIndex
        sorted[targetIndex].order = currentIndex
        chain.updatedAt = Date()
    }

    private func executeChain() async {
        runResult.reset()
        await ChainRunnerService.run(
            chain: chain,
            savedRequests: allSavedRequests,
            result: runResult
        )
    }

    // MARK: - Helpers

    private var totalDuration: TimeInterval? {
        guard let start = runResult.startedAt, let end = runResult.finishedAt else { return nil }
        return end.timeIntervalSince(start)
    }

    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": .blue
        case "POST": .green
        case "PUT": .orange
        case "PATCH": .purple
        case "DELETE": .red
        default: .secondary
        }
    }

    private func statusColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: .green
        case 300..<400: .blue
        case 400..<500: .orange
        case 500...: .red
        default: .secondary
        }
    }
}
