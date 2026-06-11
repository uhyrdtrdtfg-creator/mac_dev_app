import AppIntents

struct DevToolkitShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FormatJSONIntent(),
            phrases: [
                "Format JSON in \(.applicationName)",
                "Pretty print JSON with \(.applicationName)",
            ],
            shortTitle: "Format JSON",
            systemImageName: "curlybraces"
        )
        AppShortcut(
            intent: Base64DecodeIntent(),
            phrases: [
                "Decode Base64 in \(.applicationName)",
                "Base64 decode with \(.applicationName)",
            ],
            shortTitle: "Decode Base64",
            systemImageName: "doc.text"
        )
        AppShortcut(
            intent: GenerateUUIDIntent(),
            phrases: [
                "Generate UUID in \(.applicationName)",
                "Make a UUID with \(.applicationName)",
            ],
            shortTitle: "Generate UUID",
            systemImageName: "number.square"
        )
        AppShortcut(
            intent: HashTextIntent(),
            phrases: [
                "Hash text in \(.applicationName)",
                "Compute a hash with \(.applicationName)",
            ],
            shortTitle: "Hash Text",
            systemImageName: "number"
        )
        AppShortcut(
            intent: ConvertTimestampIntent(),
            phrases: [
                "Convert timestamp in \(.applicationName)",
                "Convert Unix timestamp with \(.applicationName)",
            ],
            shortTitle: "Convert Timestamp",
            systemImageName: "clock"
        )
    }
}
