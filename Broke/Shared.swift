//
//  Shared.swift
//  Broke
//
//  Models and storage used by both the app and the BrokeMonitor extension.
//  Everything here lives in the shared app group so the extension can read it.
//

import Foundation
import FamilyControls
import ManagedSettings
import UserNotifications

enum SharedDefaults {
    static let appGroup = "group.com.flxclxc.Broke"

    static let store: UserDefaults = {
        let store = UserDefaults(suiteName: appGroup) ?? .standard
        migrateIfNeeded(into: store)
        return store
    }()

    private static let migratedKey = "migratedToAppGroup"
    private static let legacyKeys = [
        "savedProfiles", "currentProfileId", "isBlocking", "emergencyUnblocksRemaining",
        "tagPhrase", "tagAlarms", "alarmSession",
    ]

    // Settings saved before the app group existed live in the app's standard defaults
    private static func migrateIfNeeded(into store: UserDefaults) {
        guard Bundle.main.bundleURL.pathExtension == "app", !store.bool(forKey: migratedKey) else { return }

        for key in legacyKeys where store.object(forKey: key) == nil {
            if let value = UserDefaults.standard.object(forKey: key) {
                store.set(value, forKey: key)
            }
        }
        store.set(true, forKey: migratedKey)
    }

    static func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func encode<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            store.set(data, forKey: key)
        }
    }
}

// MARK: - Profiles

struct Profile: Identifiable, Codable {
    let id: UUID
    var name: String
    var appTokens: Set<ApplicationToken>
    var categoryTokens: Set<ActivityCategoryToken>
    var webDomainTokens: Set<WebDomainToken>
    var icon: String // New property for icon

    var isDefault: Bool {
        name == "Default"
    }

    var isEmpty: Bool {
        appTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
    }

    // New initializer to support default icon
    init(name: String, appTokens: Set<ApplicationToken>, categoryTokens: Set<ActivityCategoryToken>, webDomainTokens: Set<WebDomainToken> = [], icon: String = "bell.slash") {
        self.id = UUID()
        self.name = name
        self.appTokens = appTokens
        self.categoryTokens = categoryTokens
        self.webDomainTokens = webDomainTokens
        self.icon = icon
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, appTokens, categoryTokens, webDomainTokens, icon
    }

    // Custom decoding so profiles saved before webDomainTokens existed still load
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        appTokens = try container.decode(Set<ApplicationToken>.self, forKey: .appTokens)
        categoryTokens = try container.decode(Set<ActivityCategoryToken>.self, forKey: .categoryTokens)
        webDomainTokens = try container.decodeIfPresent(Set<WebDomainToken>.self, forKey: .webDomainTokens) ?? []
        icon = try container.decode(String.self, forKey: .icon)
    }
}

enum ProfileStore {
    static let key = "savedProfiles"

    static func load() -> [Profile] {
        SharedDefaults.decode([Profile].self, forKey: key) ?? []
    }

    static func save(_ profiles: [Profile]) {
        SharedDefaults.encode(profiles, forKey: key)
    }
}

// MARK: - Shields

enum Shields {
    static func apply(_ profile: Profile, to store: ManagedSettingsStore) {
        store.shield.applications = profile.appTokens.isEmpty ? nil : profile.appTokens
        store.shield.applicationCategories = profile.categoryTokens.isEmpty ? ShieldSettings.ActivityCategoryPolicy.none : .specific(profile.categoryTokens)
        store.shield.webDomains = profile.webDomainTokens.isEmpty ? nil : profile.webDomainTokens
        store.shield.webDomainCategories = profile.categoryTokens.isEmpty ? ShieldSettings.ActivityCategoryPolicy.none : .specific(profile.categoryTokens)
        // Deleting the app would drop its shields, so prevent it while blocking
        store.application.denyAppRemoval = true
    }

    static func clear(_ store: ManagedSettingsStore) {
        store.shield.applications = nil
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.none
        store.shield.webDomains = nil
        store.shield.webDomainCategories = ShieldSettings.ActivityCategoryPolicy.none
        store.application.denyAppRemoval = false
    }
}

// MARK: - Schedules

struct BlockSchedule: Identifiable, Codable, Equatable {
    static let activityPrefix = "schedule."

    var id = UUID()
    var name: String
    var profileID: UUID
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    // Calendar weekday numbers, 1 = Sunday ... 7 = Saturday. Empty means every day.
    var weekdays: Set<Int> = []
    var isEnabled = true

    var activityName: String { Self.activityPrefix + id.uuidString }

    static func id(fromActivity name: String) -> UUID? {
        guard name.hasPrefix(activityPrefix) else { return nil }
        return UUID(uuidString: String(name.dropFirst(activityPrefix.count)))
    }

    // A window that ends earlier than it starts runs overnight; weekdays refer to the start day
    func runs(onWeekday weekday: Int) -> Bool {
        weekdays.isEmpty || weekdays.contains(weekday)
    }

    var endTimeString: String {
        let end = Calendar.current.date(from: DateComponents(hour: endHour, minute: endMinute)) ?? Date()
        return end.formatted(date: .omitted, time: .shortened)
    }

    var durationMinutes: Int {
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        return (end - start + 24 * 60) % (24 * 60)
    }
}

enum ScheduleStore {
    private static let schedulesKey = "blockSchedules"
    private static let activeKey = "activeScheduleIDs"

    static func load() -> [BlockSchedule] {
        SharedDefaults.decode([BlockSchedule].self, forKey: schedulesKey) ?? []
    }

    static func save(_ schedules: [BlockSchedule]) {
        SharedDefaults.encode(schedules, forKey: schedulesKey)
    }

    // Schedules whose shields are currently applied
    static func activeIDs() -> Set<UUID> {
        let strings = SharedDefaults.store.stringArray(forKey: activeKey) ?? []
        return Set(strings.compactMap(UUID.init(uuidString:)))
    }

    static func setActive(_ id: UUID, _ isActive: Bool) {
        var ids = activeIDs()
        if isActive {
            ids.insert(id)
        } else {
            ids.remove(id)
        }
        SharedDefaults.store.set(ids.map(\.uuidString), forKey: activeKey)
    }

    // Each schedule shields through its own store so ending one leaves the others alone
    static func managedStore(for id: UUID) -> ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(BlockSchedule.activityPrefix + id.uuidString))
    }
}

// MARK: - Stats

struct BlockSession: Identifiable, Codable {
    enum Source: String, Codable {
        case manual, schedule
    }

    enum EndReason: String, Codable {
        case tag, emergency, permissionRevoked, scheduleEnded
    }

    var id = UUID()
    var source: Source
    var scheduleID: UUID?
    var start: Date
    var end: Date?
    var endReason: EndReason?

    // Ended without the tag or the schedule finishing
    var isBreak: Bool {
        endReason == .emergency || endReason == .permissionRevoked
    }
}

enum StatsStore {
    private static let key = "blockSessions"
    private static let maxSessions = 2000

    static func load() -> [BlockSession] {
        SharedDefaults.decode([BlockSession].self, forKey: key) ?? []
    }

    private static func save(_ sessions: [BlockSession]) {
        SharedDefaults.encode(Array(sessions.suffix(maxSessions)), forKey: key)
    }

    static func start(_ source: BlockSession.Source, scheduleID: UUID? = nil) {
        var sessions = load()
        let alreadyOpen = sessions.contains { $0.end == nil && $0.source == source && $0.scheduleID == scheduleID }
        guard !alreadyOpen else { return }

        sessions.append(BlockSession(source: source, scheduleID: scheduleID, start: Date()))
        save(sessions)
    }

    static func end(_ source: BlockSession.Source, scheduleID: UUID? = nil, reason: BlockSession.EndReason) {
        var sessions = load()
        let now = Date()
        for index in sessions.indices where sessions[index].end == nil && sessions[index].source == source && sessions[index].scheduleID == scheduleID {
            sessions[index].end = now
            sessions[index].endReason = reason
        }
        save(sessions)
    }

    static func endAll(reason: BlockSession.EndReason) {
        var sessions = load()
        let now = Date()
        for index in sessions.indices where sessions[index].end == nil {
            sessions[index].end = now
            sessions[index].endReason = reason
        }
        save(sessions)
    }
}

// MARK: - Status notifications

struct StatusMessage {
    let title: String
    let body: String
}

enum StatusNotifier {
    private static let identifier = "broke.status"

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // Each status replaces the previous one so they don't pile up
    static func post(_ message: StatusMessage) {
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.threadIdentifier = "broke"

        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }
}
