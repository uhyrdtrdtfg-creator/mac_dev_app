import SwiftUI

struct JSONTreeView: View {
    let jsonString: String
    var body: some View {
        ScrollView { Text(prettyJSON).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(8) }.background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
    }
    private var prettyJSON: String {
        guard let data = jsonString.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data), let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]), let r = String(data: pretty, encoding: .utf8) else { return jsonString }; return r
    }
}
