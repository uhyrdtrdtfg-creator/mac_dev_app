import SwiftUI
import DevAppCore

public struct TOTPView: View {
    @State private var secret = ""
    @State private var algorithm: TOTPAlgorithm = .sha1
    @State private var digits = 6
    @State private var period = 30
    @State private var code = "------"
    @State private var remaining = 30
    @State private var issuer: String?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TOTP / 2FA Generator").font(.title2).fontWeight(.semibold)
                Text("Generate time-based one-time passwords from a Base32 secret or otpauth:// URI")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Secret (Base32) or otpauth:// URI").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                TextField("JBSWY3DPEHPK3PXP", text: $secret, axis: .vertical)
                    .font(.system(.body, design: .monospaced)).textFieldStyle(.plain).lineLimit(1...3)
                    .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 16) {
                Picker("Algorithm", selection: $algorithm) {
                    ForEach(TOTPAlgorithm.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu).fixedSize()
                Picker("Digits", selection: $digits) {
                    Text("6").tag(6); Text("7").tag(7); Text("8").tag(8)
                }.pickerStyle(.segmented).frame(width: 130)
                Stepper("Period: \(period)s", value: $period, in: 10...120, step: 5).fixedSize()
            }

            // Code display
            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(.quaternary, lineWidth: 5).frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: CGFloat(remaining) / CGFloat(max(period, 1)))
                        .stroke(remaining <= 5 ? Color.red : Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 56, height: 56)
                        .animation(.linear(duration: 0.5), value: remaining)
                    Text("\(remaining)").font(.system(.body, design: .rounded)).fontWeight(.semibold).monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let issuer { Text(issuer).font(.caption).foregroundStyle(.secondary) }
                    Text(spacedCode)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundStyle(secret.isEmpty ? .tertiary : .primary)
                        .textSelection(.enabled)
                }
                Spacer()
                if code != "------" { CopyButton(text: code) }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Secrets are processed locally and never stored or transmitted.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding()
        .onChange(of: secret) { _, _ in handleSecretChange() }
        .onChange(of: algorithm) { _, _ in refresh() }
        .onChange(of: digits) { _, _ in refresh() }
        .onChange(of: period) { _, _ in refresh() }
        .onReceive(timer) { _ in refresh() }
        .onAppear { refresh() }
    }

    private var spacedCode: String {
        guard code.count == 6 else { return code }
        let mid = code.index(code.startIndex, offsetBy: 3)
        return "\(code[..<mid]) \(code[mid...])"
    }

    private func handleSecretChange() {
        // Auto-fill settings from an otpauth:// URI.
        if secret.lowercased().hasPrefix("otpauth://"), let config = TOTPGenerator.parseOTPAuth(secret) {
            algorithm = config.algorithm
            digits = config.digits
            period = config.period
            issuer = config.issuer ?? config.label
            secret = config.secret   // replace URI with the raw secret
        }
        refresh()
    }

    private func refresh() {
        let trimmed = secret.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.lowercased().hasPrefix("otpauth://") else {
            code = String(repeating: "-", count: digits); remaining = period; return
        }
        code = TOTPGenerator.generate(secretBase32: trimmed, algorithm: algorithm, digits: digits, period: period)
            ?? String(repeating: "-", count: digits)
        remaining = TOTPGenerator.remainingSeconds(period: period)
    }
}

extension TOTPView {
    public static let descriptor = ToolDescriptor(
        id: "totp",
        name: "TOTP / 2FA",
        icon: "lock.rotation",
        category: .crypto,
        searchKeywords: ["totp", "2fa", "otp", "authenticator", "mfa", "google authenticator", "动态口令", "验证码", "两步验证"]
    )
}
