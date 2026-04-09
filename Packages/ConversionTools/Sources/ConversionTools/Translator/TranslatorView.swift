import SwiftUI
import Translation
import DevAppCore

// MARK: - TranslatorViewModel

@Observable
@MainActor
final class TranslatorViewModel {
    var inputText = ""
    var outputText = ""
    var detectedLanguage: DetectedLanguage?
    var sourceLanguageCode = "auto"
    var targetLanguageCode = "en"
    var isTranslating = false
    var errorMessage: String?
    var translationConfig: TranslationSession.Configuration?

    // Called from translationTask closure; session is provided by the system
    // The nonisolated(unsafe) wrapper allows calling nonisolated translate() from @MainActor context
    func handleTranslationSession(_ session: TranslationSession) async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isTranslating = false
            return
        }
        do {
            nonisolated(unsafe) let s = session
            let result = try await s.translate(trimmed)
            outputText = result.targetText
            isTranslating = false
        } catch {
            errorMessage = error.localizedDescription
            isTranslating = false
        }
    }

    func updateDetectedLanguage(for text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            detectedLanguage = nil
            return
        }
        detectedLanguage = TranslationService.detectLanguage(trimmed)
        guard let detected = detectedLanguage else { return }
        let isAsian = detected.code.hasPrefix("zh") || detected.code == "ja" || detected.code == "ko"
        let targetIsAsian = targetLanguageCode.hasPrefix("zh") || targetLanguageCode == "ja" || targetLanguageCode == "ko"
        if isAsian && targetIsAsian {
            targetLanguageCode = "en"
        } else if detected.code == "en" && targetLanguageCode == "en" {
            targetLanguageCode = "zh-Hans"
        }
    }

    func triggerTranslation() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        isTranslating = true
        outputText = ""

        let sourceCode = sourceLanguageCode == "auto"
            ? (detectedLanguage?.code ?? "en")
            : sourceLanguageCode

        let sourceLang = TranslationService.localeLanguage(for: sourceCode)
        let targetLang = TranslationService.localeLanguage(for: targetLanguageCode)

        let newConfig = TranslationSession.Configuration(source: sourceLang, target: targetLang)
        if translationConfig == newConfig {
            translationConfig?.invalidate()
        } else {
            translationConfig = newConfig
        }
    }

    func swapLanguages() {
        let newSource = sourceLanguageCode == "auto"
            ? (detectedLanguage?.code ?? "en")
            : sourceLanguageCode
        sourceLanguageCode = targetLanguageCode
        targetLanguageCode = newSource

        let tmp = inputText
        inputText = outputText
        outputText = tmp
    }
}

// MARK: - TranslatorView

public struct TranslatorView: View {
    @State private var vm = TranslatorViewModel()

    public init() {}

    private var languageOptions: [(code: String, name: String)] {
        [("auto", "Auto Detect")] + TranslationService.supportedLanguages
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Translator")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Auto-detect language and translate between 20+ languages")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Language selectors row
            HStack(spacing: 12) {
                // Source language
                VStack(alignment: .leading, spacing: 4) {
                    Text("FROM")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Picker("Source", selection: $vm.sourceLanguageCode) {
                        ForEach(languageOptions, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                // Detected language badge
                if vm.sourceLanguageCode == "auto", let detected = vm.detectedLanguage {
                    VStack(spacing: 2) {
                        Text("Detected")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(detected.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }

                // Swap button
                Button {
                    vm.swapLanguages()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.bordered)
                .help("Swap languages and text")

                // Target language
                VStack(alignment: .leading, spacing: 4) {
                    Text("TO")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Picker("Target", selection: $vm.targetLanguageCode) {
                        ForEach(TranslationService.supportedLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                Spacer()

                // Translate button
                Button {
                    vm.triggerTranslation()
                } label: {
                    if vm.isTranslating {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Translating...")
                        }
                    } else {
                        Label("Translate", systemImage: "translate")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isTranslating)
                .keyboardShortcut(.return, modifiers: .command)
            }

            // Error banner
            if let errorMessage = vm.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.vertical, 2)
            }

            // Text panels
            HStack(spacing: 16) {
                // Input panel
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("SOURCE")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Spacer()
                        CopyButton(text: vm.inputText)
                    }
                    TextEditor(text: $vm.inputText)
                        .font(.system(.body))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(.background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
                        .frame(minHeight: 200)
                }

                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)
                    .padding(.top, 24)

                // Output panel
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("TRANSLATION")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Spacer()
                        CopyButton(text: vm.outputText)
                    }
                    TextEditor(text: .constant(vm.outputText))
                        .font(.system(.body))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(.background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
                        .frame(minHeight: 200)
                }
            }
        }
        .padding(20)
        .onChange(of: vm.inputText) { _, newValue in
            vm.updateDetectedLanguage(for: newValue)
        }
        .translationTask(vm.translationConfig) { session in
            await vm.handleTranslationSession(session)
        }
    }
}

extension TranslatorView {
    public static let descriptor = ToolDescriptor(
        id: "translator",
        name: "Translator",
        icon: "translate",
        category: .conversion,
        searchKeywords: ["translate", "language", "翻译", "语言", "中文", "英文", "日文", "japanese", "chinese"]
    )
}
