import SwiftUI
import SwiftData

struct OAuth2AuthPane: View {
    @Binding var config: OAuth2Config
    @Query(filter: #Predicate<EnvironmentModel> { $0.isActive }) private var activeEnvironments: [EnvironmentModel]

    @State private var isFetching = false
    @State private var fetchError: String?
    @State private var showSaveToEnv = false
    @State private var envVariableName = "ACCESS_TOKEN"
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Grant Type", selection: $config.grantType) {
                ForEach(OAuth2GrantType.allCases) { g in
                    Text(g.displayName).tag(g)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch config.grantType {
            case .clientCredentials:
                field("Token URL", placeholder: "https://auth.example.com/oauth/token", text: $config.tokenURL)
                HStack(spacing: 14) {
                    field("Client ID", placeholder: "client-id", text: $config.clientID)
                    secureField("Client Secret", placeholder: "client-secret", text: $config.clientSecret)
                }
                field("Scopes", placeholder: "read write (space-separated)", text: $config.scopes)
                Toggle("Send client credentials in body", isOn: $config.clientAuthInBody)
                    .font(.caption)
            case .authorizationCodePKCE:
                field("Authorization URL", placeholder: "https://auth.example.com/oauth/authorize", text: $config.authorizationURL)
                field("Token URL", placeholder: "https://auth.example.com/oauth/token", text: $config.tokenURL)
                HStack(spacing: 14) {
                    field("Client ID", placeholder: "client-id", text: $config.clientID)
                    secureField("Client Secret (optional)", placeholder: "leave empty for public clients", text: $config.clientSecret)
                }
                HStack(spacing: 14) {
                    field("Scopes", placeholder: "read write (space-separated)", text: $config.scopes)
                    field("Redirect Port", placeholder: "53682", text: portBinding)
                        .frame(width: 120)
                }
                Toggle("Send client credentials in body", isOn: $config.clientAuthInBody)
                    .font(.caption)
            case .refreshTokenOnly:
                field("Token URL", placeholder: "https://auth.example.com/oauth/token", text: $config.tokenURL)
                HStack(spacing: 14) {
                    field("Client ID", placeholder: "client-id", text: $config.clientID)
                    secureField("Client Secret", placeholder: "client-secret", text: $config.clientSecret)
                }
                secureField("Refresh Token", placeholder: "paste an existing refresh token", text: refreshTokenBinding)
            }

            HStack(spacing: 8) {
                Button {
                    fetchToken(grant: config.grantType)
                } label: {
                    if isFetching {
                        HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Fetching…") }
                    } else {
                        Text(config.grantType == .authorizationCodePKCE ? "Fetch Token (opens browser)" : "Fetch Token")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isFetching || config.tokenURL.trimmingCharacters(in: .whitespaces).isEmpty)

                if let error = fetchError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            if let tokens = config.tokens, !tokens.accessToken.isEmpty {
                tokenStatus(tokens)
            }
        }
    }

    // MARK: - Token status

    @ViewBuilder
    private func tokenStatus(_ tokens: OAuth2Tokens) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.caption)
                Text(maskedToken(tokens.accessToken))
                    .font(.system(.caption, design: .monospaced))
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(tokens.accessToken, forType: .string)
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.caption)
                }
                .buttonStyle(.plain)
                .help("Copy access token")

                if let expiresAt = tokens.expiresAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(expiryText(expiresAt, now: context.date))
                            .font(.caption)
                            .foregroundStyle(expiresAt > context.date ? Color.secondary : Color.red)
                    }
                }

                if tokens.refreshToken?.isEmpty == false {
                    Button("Refresh") { fetchToken(grant: .refreshTokenOnly) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isFetching)
                }

                Button("Save token to environment…") { showSaveToEnv = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(activeEnvironments.isEmpty)
                    .help(activeEnvironments.isEmpty ? "Activate an environment first (globe menu)" : "Store the access token as a variable in the active environment")
                    .popover(isPresented: $showSaveToEnv) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Save Token to \(activeEnvironments.first?.name ?? "Environment")").font(.headline)
                            TextField("Variable name", text: $envVariableName)
                                .textFieldStyle(.roundedBorder)
                            HStack {
                                Spacer()
                                Button("Cancel") { showSaveToEnv = false }.buttonStyle(.bordered)
                                Button("Save") {
                                    saveTokenToEnvironment(tokens.accessToken)
                                    showSaveToEnv = false
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(envVariableName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        .padding()
                        .frame(width: 280)
                    }
            }
            if activeEnvironments.isEmpty {
                Text("No active environment — activate one to save the token as a variable.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.fill.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func maskedToken(_ token: String) -> String {
        token.count <= 8 ? "••••••••" : "\(token.prefix(6))…\(token.suffix(4))"
    }

    private func expiryText(_ expiresAt: Date, now: Date) -> String {
        let remaining = Int(expiresAt.timeIntervalSince(now))
        guard remaining > 0 else { return "Expired" }
        if remaining >= 3600 { return "Expires in \(remaining / 3600)h \((remaining % 3600) / 60)m" }
        if remaining >= 60 { return "Expires in \(remaining / 60)m \(remaining % 60)s" }
        return "Expires in \(remaining)s"
    }

    // MARK: - Actions

    private func fetchToken(grant: OAuth2GrantType) {
        isFetching = true
        fetchError = nil
        let current = config
        Task {
            do {
                let tokens: OAuth2Tokens
                switch grant {
                case .clientCredentials: tokens = try await OAuth2Service.fetchTokenClientCredentials(current)
                case .authorizationCodePKCE: tokens = try await OAuth2Service.authorizationCodePKCE(current)
                case .refreshTokenOnly: tokens = try await OAuth2Service.refreshToken(current)
                }
                config.tokens = tokens
            } catch {
                fetchError = (error as? OAuth2Error)?.errorDescription ?? error.localizedDescription
            }
            isFetching = false
        }
    }

    private func saveTokenToEnvironment(_ token: String) {
        guard let env = activeEnvironments.first else { return }
        var vars = env.variables
        vars[envVariableName.trimmingCharacters(in: .whitespaces)] = token
        env.variables = vars
        ScriptEngine.setEnvironment(vars)
    }

    // MARK: - Bindings

    private var portBinding: Binding<String> {
        Binding(
            get: { String(config.redirectPort) },
            set: { newValue in
                if let port = Int(newValue), (1...65535).contains(port) { config.redirectPort = port }
            }
        )
    }

    private var refreshTokenBinding: Binding<String> {
        Binding(
            get: { config.tokens?.refreshToken ?? "" },
            set: { newValue in
                var tokens = config.tokens ?? OAuth2Tokens(accessToken: "")
                tokens.refreshToken = newValue.isEmpty ? nil : newValue
                config.tokens = tokens
            }
        )
    }

    // MARK: - Field helpers

    private func field(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
        }
    }

    private func secureField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
            SecureField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
        }
    }
}
