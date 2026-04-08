import SwiftUI

public struct InputOutputView<ConfigContent: View>: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    @Binding var input: String
    @Binding var output: String
    let inputLabel: LocalizedStringKey
    let outputLabel: LocalizedStringKey
    let configContent: () -> ConfigContent

    public init(
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        input: Binding<String>,
        output: Binding<String>,
        inputLabel: LocalizedStringKey = "Input",
        outputLabel: LocalizedStringKey = "Output",
        @ViewBuilder configContent: @escaping () -> ConfigContent = { EmptyView() }
    ) {
        self.title = title
        self.description = description
        self._input = input
        self._output = output
        self.inputLabel = inputLabel
        self.outputLabel = outputLabel
        self.configContent = configContent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Config area
            configContent()
                .padding(.horizontal, 2)

            // Input / Output panels
            HStack(spacing: 16) {
                // Input panel
                VStack(alignment: .leading, spacing: 6) {
                    Text(inputLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TextEditor(text: $input)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(.background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.quaternary, lineWidth: 1)
                        )
                }

                // Arrow indicator
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)

                // Output panel
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(outputLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        CopyButton(text: output)
                    }
                    TextEditor(text: .constant(output))
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(.background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.quaternary, lineWidth: 1)
                        )
                }
            }
        }
        .padding(20)
    }
}
