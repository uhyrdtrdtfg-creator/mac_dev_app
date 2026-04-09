import SwiftUI
import DevAppCore

public struct TranslatorView: View {
    @State private var inputText = ""
    @State private var outputText = ""
    @State private var detectedLanguage: DetectedLanguage?
    @State private var sourceLanguageCode = "auto"
    @State private var targetLanguageCode = "en"
    @State private var isTranslating = false
    @State private var errorMessage: String?

    public init() {}

    private var languageOptions: [(code: String, name: String)] {
        [("auto", "Auto Detect")] + TranslationService.supportedLanguages
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Translator")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Auto-detect language and translate using Microsoft Translator (free, no API key)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Language selectors
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FROM").font(.caption2).fontWeight(.medium).foregroundStyle(.secondary)
                    Picker("Source", selection: $sourceLanguageCode) {
                        ForEach(languageOptions, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                if sourceLanguageCode == "auto", let detected = detectedLanguage {
                    Text(detected.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }

                Button {
                    swapLanguages()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.bordered)

                VStack(alignment: .leading, spacing: 4) {
                    Text("TO").font(.caption2).fontWeight(.medium).foregroundStyle(.secondary)
                    Picker("Target", selection: $targetLanguageCode) {
                        ForEach(TranslationService.supportedLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                Spacer()

                Button {
                    doTranslate()
                } label: {
                    if isTranslating {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Translate", systemImage: "translate")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTranslating)
                .keyboardShortcut(.return, modifiers: .command)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Text panels
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("SOURCE").font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                        Spacer()
                        CopyButton(text: inputText)
                    }
                    TextEditor(text: $inputText)
                        .font(.system(.body))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(.background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
                }

                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("TRANSLATION").font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                        Spacer()
                        CopyButton(text: outputText)
                    }
                    TextEditor(text: .constant(outputText))
                        .font(.system(.body))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(.background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
                }
            }
        }
        .padding(20)
        .onChange(of: inputText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count >= 3 {
                detectedLanguage = TranslationService.detectLanguage(trimmed)
                autoSetTarget()
            } else {
                detectedLanguage = nil
            }
        }
    }

    private func autoSetTarget() {
        guard let detected = detectedLanguage else { return }
        if detected.code.hasPrefix("zh") || detected.code == "ja" || detected.code == "ko" {
            if targetLanguageCode.hasPrefix("zh") || targetLanguageCode == "ja" || targetLanguageCode == "ko" {
                targetLanguageCode = "en"
            }
        } else if detected.code == "en" && targetLanguageCode == "en" {
            targetLanguageCode = "zh-Hans"
        }
    }

    private func swapLanguages() {
        let src = sourceLanguageCode == "auto" ? (detectedLanguage?.code ?? "en") : sourceLanguageCode
        sourceLanguageCode = targetLanguageCode
        targetLanguageCode = src
        let tmp = inputText; inputText = outputText; outputText = tmp
    }

    private func doTranslate() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isTranslating = true
        errorMessage = nil
        outputText = ""

        let source = sourceLanguageCode == "auto" ? (detectedLanguage?.code ?? "auto") : sourceLanguageCode

        Task {
            do {
                outputText = try await TranslationService.translate(trimmed, from: source, to: targetLanguageCode)
            } catch {
                errorMessage = error.localizedDescription
            }
            isTranslating = false
        }
    }
}

extension TranslatorView {
    public static let descriptor = ToolDescriptor(
        id: "translator",
        name: "Translator",
        icon: "translate",
        category: .conversion,
        searchKeywords: ["translate", "language", "翻译", "语言", "中文", "英文", "日文"]
    )
}
