import SwiftUI
import SwiftData

struct ChainListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChainModel.updatedAt, order: .reverse)
    private var chains: [ChainModel]

    @State private var searchText = ""

    let onSelect: (ChainModel) -> Void

    var filteredChains: [ChainModel] {
        if searchText.isEmpty { return chains }
        let query = searchText.lowercased()
        return chains.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Chains")
                    .font(.headline)
                Spacer()
                Button {
                    let chain = ChainModel(name: "New Chain")
                    modelContext.insert(chain)
                    onSelect(chain)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("New Chain")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            TextField("Search...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            List {
                ForEach(filteredChains) { chain in
                    Button {
                        onSelect(chain)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chain.name)
                                .font(.body)
                                .lineLimit(1)
                            Text("\(chain.steps.count) steps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(chain)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}
