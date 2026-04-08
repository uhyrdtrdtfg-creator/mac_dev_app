import SwiftUI

enum BodyType: String, CaseIterable, Identifiable {
    case none = "None"
    case json = "JSON"
    case formData = "Form Data"
    case raw = "Raw"

    var id: String { rawValue }
}

struct BodyEditor: View {
    @Binding var bodyType: BodyType
    @Binding var jsonBody: String
    @Binding var formDataPairs: [KeyValuePair]
    @Binding var rawBody: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Body Type", selection: $bodyType) {
                ForEach(BodyType.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch bodyType {
            case .none:
                ContentUnavailableView("No Body", systemImage: "doc")
            case .json:
                TextEditor(text: $jsonBody)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.fill.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(minHeight: 100)
            case .formData:
                KeyValueEditor(pairs: $formDataPairs)
            case .raw:
                TextEditor(text: $rawBody)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.fill.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(minHeight: 100)
            }
        }
    }
}
