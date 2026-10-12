//
//  TagActions.swift
//  Broke
//
//  What a valid tag tap does, shared by the in-app scan button and the Shortcuts
//  automation intent so both behave identically.
//

import Foundation
import AppIntents

enum TagSecurity {
    private static let phraseKey = "tagPhrase"
    private static let pairedKey = "pairedTagIDs"

    // Random per-install phrase, so a tag written from the public source code can't unlock this phone.
    // Also used as the key for the Shortcuts automation.
    static let phrase: String = {
        if let phrase = SharedDefaults.store.string(forKey: phraseKey) {
            return phrase
        }
        let phrase = "BROKE-\(UUID().uuidString)"
        SharedDefaults.store.set(phrase, forKey: phraseKey)
        return phrase
    }()

    // Serial numbers of tags created on this phone; a copied phrase on another tag won't match
    static var pairedTagIDs: Set<String> {
        Set(SharedDefaults.store.stringArray(forKey: pairedKey) ?? [])
    }

    static func pair(_ tagID: String) {
        SharedDefaults.store.set(Array(pairedTagIDs.union([tagID])), forKey: pairedKey)
    }

    static func forgetAllTags() {
        SharedDefaults.store.removeObject(forKey: pairedKey)
    }

    static func isValid(_ scan: TagScan) -> Bool {
        scan.text == phrase && pairedTagIDs.contains(scan.tagID)
    }
}

enum TagAction {
    case dismissWakeAlarm
    case dismissBedtimeAlarm(blockFirst: Bool)
    case unblock
    case endSchedules
    case block
}

enum TagActionError: Error {
    case notAuthorized
    case emptyProfile
}

enum TagActions {
    // Decided before scanning so the user isn't asked to scan for something that can't happen
    static func plan() -> Result<TagAction, TagActionError> {
        let blocker = AppBlocker.shared
        let scheduleActive = !ScheduleManager.shared.activeIDs.isEmpty

        switch TagAlarmManager.shared.activeKind {
        case .wakeUp:
            return .success(.dismissWakeAlarm)
        case .bedtime:
            if blocker.isBlocking || scheduleActive {
                return .success(.dismissBedtimeAlarm(blockFirst: false))
            }
            return validateBlock().map { .dismissBedtimeAlarm(blockFirst: true) }
        case nil:
            if blocker.isBlocking {
                return .success(.unblock)
            }
            if scheduleActive {
                return .success(.endSchedules)
            }
            return validateBlock().map { .block }
        }
    }

    // Returns what happened, for the status notification
    @discardableResult
    static func perform(_ action: TagAction) -> StatusMessage {
        let blocker = AppBlocker.shared
        let profile = ProfileManager.shared.currentProfile

        switch action {
        case .dismissWakeAlarm:
            TagAlarmManager.shared.endSession()
            return StatusMessage(title: "Alarm stopped", body: "Good morning!")
        case .dismissBedtimeAlarm(let blockFirst):
            if blockFirst {
                blocker.block(with: profile)
            }
            TagAlarmManager.shared.endSession()
            return StatusMessage(title: "Phone bricked", body: "Good night! Tap your tag in the morning to unbrick.")
        case .unblock:
            let started = StatsStore.load().last { $0.source == .manual && $0.end == nil }?.start
            blocker.unblock()
            let body = started.map { "You were bricked for \(durationString(Date().timeIntervalSince($0)))." } ?? "Your apps are unblocked."
            return StatusMessage(title: "Phone unbricked", body: body)
        case .endSchedules:
            ScheduleManager.shared.endActiveEarly(reason: .tag)
            return StatusMessage(title: "Scheduled block ended", body: "Ended early with your tag.")
        case .block:
            blocker.block(with: profile)
            return StatusMessage(title: "Phone bricked", body: "\(profile.name) · Tap your tag to unbrick.")
        }
    }

    private static func validateBlock() -> Result<Void, TagActionError> {
        guard AppBlocker.shared.isAuthorized else {
            return .failure(.notAuthorized)
        }
        guard !ProfileManager.shared.currentProfile.isEmpty else {
            return .failure(.emptyProfile)
        }
        return .success(())
    }
}

// MARK: - Shortcuts automation

// Run from a Shortcuts NFC automation so tapping the tag works without opening the app.
// The key stops it from being run by just any shortcut.
struct TapBrokerTagIntent: AppIntent {
    static var title: LocalizedStringResource = "Tap Broker Tag"
    static var description = IntentDescription("Blocks or unblocks your phone, or stops a Broke alarm. Use it in an NFC automation with your Broker tag.")
    static var openAppWhenRun = false

    @Parameter(title: "Key")
    var key: String

    @MainActor
    func perform() async throws -> some IntentResult {
        guard key == TagSecurity.phrase else {
            throw fail(.invalidKey)
        }
        _ = await AppBlocker.shared.ensureAuthorized()

        switch TagActions.plan() {
        case .success(let action):
            // Broke posts its own notification, so the automation can run silently
            StatusNotifier.post(TagActions.perform(action))
            return .result()
        case .failure(.notAuthorized):
            throw fail(.notAuthorized)
        case .failure(.emptyProfile):
            throw fail(.emptyProfile)
        }
    }

    // Errors are otherwise invisible when the automation runs without notifications
    private func fail(_ error: TapBrokerTagError) -> TapBrokerTagError {
        StatusNotifier.post(StatusMessage(title: "Broke couldn't do that", body: String(localized: error.localizedStringResource)))
        return error
    }
}

enum TapBrokerTagError: Error, CustomLocalizedStringResourceConvertible {
    case invalidKey
    case notAuthorized
    case emptyProfile

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidKey: return "That key doesn't match. Copy it again from Broke → Tags & Shortcut."
        case .notAuthorized: return "Open Broke and allow Screen Time access first."
        case .emptyProfile: return "The current Broke profile has nothing to block."
        }
    }
}
