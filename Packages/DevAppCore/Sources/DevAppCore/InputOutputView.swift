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
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            configContent()

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(inputLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TextEditor(text: $input)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(outputLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        CopyButton(text: output)
                    }
                    TextEditor(text: .constant(output))
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
    }
}
