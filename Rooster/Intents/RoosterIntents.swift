import AppIntents
import Foundation

// MARK: - Activate

struct ActivateRoosterIntent: AppIntent {
    static var title: LocalizedStringResource = "Activate Rooster"
    static var description = IntentDescription("Keeps your Mac awake.")

    @Parameter(title: "Minutes", description: "Duration in minutes. Use 0 for indefinite.", default: 0)
    var minutes: Int

    func perform() async throws -> some IntentResult {
        let seconds = TimeInterval(minutes) * 60
        await MainActor.run {
            AwakeManager.shared.activate(seconds: seconds, reason: .shortcut)
        }
        return .result()
    }
}

// MARK: - Deactivate

struct DeactivateRoosterIntent: AppIntent {
    static var title: LocalizedStringResource = "Deactivate Rooster"
    static var description = IntentDescription("Allows your Mac to sleep normally.")

    func perform() async throws -> some IntentResult {
        await MainActor.run { AwakeManager.shared.deactivate() }
        return .result()
    }
}

// MARK: - Toggle

struct ToggleRoosterIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Rooster"
    static var description = IntentDescription("Toggles Rooster on or off.")

    func perform() async throws -> some IntentResult {
        await MainActor.run { AwakeManager.shared.toggle() }
        return .result()
    }
}
