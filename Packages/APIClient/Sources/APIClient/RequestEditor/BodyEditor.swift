import SwiftUI

enum BodyType: String, CaseIterable, Identifiable {
    case none = "None"
    case json = "JSON"
    case formData = "Form Data"
    case raw = "Raw"
    case graphql = "GraphQL"
    case multipart = "Multipart"
    case binary = "Binary"

    var id: String { rawValue }
}

struct BodyEditor: View {
    @Binding var bodyType: BodyType
    @Binding var jsonBody: String
    @Binding var formDataPairs: [KeyValuePair]
    @Binding var rawBody: String
    @Binding var graphqlQuery: String
    @Binding var graphqlVariables: String
    @Binding var multipartParts: [MultipartPart]
    @Binding var binaryFilePath: String
    @Binding var binaryMimeType: String
    var url: String = ""
    var headers: [KeyValuePair] = []
    var auth: AuthType? = nil

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
                CodeEditorView(text: $jsonBody)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
                    .frame(minHeight: 100)
            case .formData:
                KeyValueEditor(pairs: $formDataPairs)
            case .raw:
                CodeEditorView(text: $rawBody)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
                    .frame(minHeight: 100)
            case .graphql:
                GraphQLBodyEditor(query: $graphqlQuery, variables: $graphqlVariables, url: url, headers: headers, auth: auth)
            case .multipart:
                MultipartBodyEditor(parts: $multipartParts)
            case .binary:
                BinaryBodyEditor(filePath: $binaryFilePath, mimeType: $binaryMimeType)
            }
        }
    }
}
