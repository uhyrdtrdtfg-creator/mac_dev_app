import SwiftUI
import SwiftData

/// View for managing HTTP cookies
public struct CookieManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CookieModel.domain) private var cookies: [CookieModel]

    @State private var showAddCookie = false
    @State private var selectedCookie: CookieModel?

    // New cookie form fields
    @State private var newDomain = ""
    @State private var newName = ""
    @State private var newValue = ""
    @State private var newPath = "/"
    @State private var newIsSecure = false
    @State private var newIsHttpOnly = false
    @State private var newHasExpiry = false
    @State private var newExpiryDate = Date().addingTimeInterval(86400 * 30) // 30 days default

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Title bar with close button
            HStack {
                Text("Cookie Manager")
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
                // Cookie list grouped by domain
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Cookies")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            resetNewCookieForm()
                            showAddCookie = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)

                        Button {
                            deleteExpiredCookies()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .help("Delete expired cookies")
                    }
                    .padding(8)

                Divider()

                List(selection: $selectedCookie) {
                    ForEach(groupedCookies, id: \.key) { domain, domainCookies in
                        Section(header: Text(domain).font(.caption).foregroundStyle(.secondary)) {
                            ForEach(domainCookies) { cookie in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cookie.name)
                                            .font(.body)
                                        Text(cookie.value)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if cookie.isExpired {
                                        Text("Expired")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                }
                                .tag(cookie)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        deleteCookie(cookie)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 200, maxWidth: 300)

            // Cookie details / editor
            VStack(alignment: .leading, spacing: 0) {
                if let cookie = selectedCookie {
                    cookieDetailView(cookie)
                } else {
                    ContentUnavailableView(
                        "No Cookie Selected",
                        systemImage: "shippingbox",
                        description: Text("Select a cookie to view its details")
                    )
                }
            }
            .frame(minWidth: 300)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $showAddCookie) {
            addCookieSheet
        }
    }

    private var groupedCookies: [(key: String, value: [CookieModel])] {
        Dictionary(grouping: cookies) { $0.domain }
            .sorted { $0.key < $1.key }
    }

    @ViewBuilder
    private func cookieDetailView(_ cookie: CookieModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(cookie.name)
                    .font(.headline)
                Spacer()
                Button("Delete", role: .destructive) {
                    deleteCookie(cookie)
                }
                .buttonStyle(.bordered)
            }
            .padding(8)

            Divider()

            Form {
                Section("Cookie Details") {
                    LabeledContent("Domain") {
                        Text(cookie.domain)
                            .textSelection(.enabled)
                    }
                    LabeledContent("Name") {
                        Text(cookie.name)
                            .textSelection(.enabled)
                    }
                    LabeledContent("Value") {
                        Text(cookie.value)
                            .textSelection(.enabled)
                            .lineLimit(3)
                    }
                    LabeledContent("Path") {
                        Text(cookie.path)
                    }
                }

                Section("Attributes") {
                    LabeledContent("Secure") {
                        Image(systemName: cookie.isSecure ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(cookie.isSecure ? .green : .secondary)
                    }
                    LabeledContent("HttpOnly") {
                        Image(systemName: cookie.isHttpOnly ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(cookie.isHttpOnly ? .green : .secondary)
                    }
                    if let expiresAt = cookie.expiresAt {
                        LabeledContent("Expires") {
                            VStack(alignment: .trailing) {
                                Text(expiresAt, style: .date)
                                Text(expiresAt, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        LabeledContent("Expires") {
                            Text("Session")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Timestamps") {
                    LabeledContent("Created") {
                        Text(cookie.createdAt, style: .date)
                    }
                    LabeledContent("Updated") {
                        Text(cookie.updatedAt, style: .date)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private var addCookieSheet: some View {
        VStack(spacing: 16) {
            Text("Add Cookie")
                .font(.headline)

            Form {
                TextField("Domain", text: $newDomain)
                    .textFieldStyle(.roundedBorder)
                TextField("Name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                TextField("Value", text: $newValue)
                    .textFieldStyle(.roundedBorder)
                TextField("Path", text: $newPath)
                    .textFieldStyle(.roundedBorder)

                Toggle("Secure", isOn: $newIsSecure)
                Toggle("HttpOnly", isOn: $newIsHttpOnly)

                Toggle("Has Expiry", isOn: $newHasExpiry)
                if newHasExpiry {
                    DatePicker("Expires", selection: $newExpiryDate)
                }
            }
            .frame(width: 350)

            HStack {
                Button("Cancel") {
                    showAddCookie = false
                }
                .buttonStyle(.bordered)

                Button("Add") {
                    addCookie()
                    showAddCookie = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newDomain.isEmpty || newName.isEmpty)
            }
        }
        .padding(20)
    }

    private func resetNewCookieForm() {
        newDomain = ""
        newName = ""
        newValue = ""
        newPath = "/"
        newIsSecure = false
        newIsHttpOnly = false
        newHasExpiry = false
        newExpiryDate = Date().addingTimeInterval(86400 * 30)
    }

    private func addCookie() {
        let cookie = CookieModel(
            domain: newDomain,
            name: newName,
            value: newValue,
            path: newPath,
            expiresAt: newHasExpiry ? newExpiryDate : nil,
            isSecure: newIsSecure,
            isHttpOnly: newIsHttpOnly
        )
        modelContext.insert(cookie)
        selectedCookie = cookie
    }

    private func deleteCookie(_ cookie: CookieModel) {
        if selectedCookie == cookie {
            selectedCookie = nil
        }
        modelContext.delete(cookie)
    }

    private func deleteExpiredCookies() {
        for cookie in cookies where cookie.isExpired {
            if selectedCookie == cookie {
                selectedCookie = nil
            }
            modelContext.delete(cookie)
        }
    }
}
