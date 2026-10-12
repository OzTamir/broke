//
//  TagAlarms.swift
//  Broke
//
//  Alarms that only go away when you scan your Broker tag.
//  Wake-up alarms stop on a tag scan; bedtime alarms stop once the phone is blocked.
//  AlarmKit always shows a system Stop button, so pressing it without scanning
//  schedules a follow-up alarm a couple of minutes later.
//

import SwiftUI
import AppIntents
import ActivityKit
import AlarmKit

struct TagAlarm: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case wakeUp, bedtime

        var id: String { rawValue }

        var label: String {
            switch self {
            case .wakeUp: return "Wake Up"
            case .bedtime: return "Bedtime"
            }
        }

        var icon: String {
            switch self {
            case .wakeUp: return "sunrise.fill"
            case .bedtime: return "moon.fill"
            }
        }

        var alertTitle: String {
            switch self {
            case .wakeUp: return "Wake up! Scan your tag to stop"
            case .bedtime: return "Bedtime! Brick your phone to stop"
            }
        }
    }

    var id = UUID()
    var kind: Kind
    var hour: Int
    var minute: Int
    // Calendar weekday numbers, 1 = Sunday ... 7 = Saturday. Empty means ring once.
    var weekdays: Set<Int>
    var isEnabled = true
}

// The alarm currently demanding a tag scan, shared between the app and its intents
struct AlarmSession: Codable {
    var kind: TagAlarm.Kind
    var parentID: UUID
    var followUpIDs: [UUID] = []
    var followUpCount = 0
    var updatedAt = Date()

    private static let key = "alarmSession"

    static func load() -> AlarmSession? {
        guard let data = SharedDefaults.store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AlarmSession.self, from: data)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            SharedDefaults.store.set(data, forKey: Self.key)
        }
    }

    static func clear() {
        SharedDefaults.store.removeObject(forKey: key)
    }

    func contains(_ id: UUID) -> Bool {
        parentID == id || followUpIDs.contains(id)
    }
}

struct TagAlarmMetadata: AlarmMetadata {
    var kind: TagAlarm.Kind
}

class TagAlarmManager: ObservableObject {
    static let shared = TagAlarmManager()

    static let followUpDelay: TimeInterval = 120
    // Stops nagging after about an hour so a forgotten alarm can't ring forever
    static let maxFollowUps = 30

    private static let alarmsKey = "tagAlarms"

    @Published var alarms: [TagAlarm] = []
    @Published var activeKind: TagAlarm.Kind?
    @Published var isAuthorized = false

    static var isSupported: Bool {
        if #available(iOS 26.1, *) {
            return true
        }
        return false
    }

    init() {
        alarms = Self.loadAlarms()
        activeKind = AlarmSession.load()?.kind
        if #available(iOS 26.1, *) {
            isAuthorized = AlarmManager.shared.authorizationState == .authorized
            observeAlarms()
        }
    }

    // MARK: - Persistence

    static func loadAlarms() -> [TagAlarm] {
        guard let data = SharedDefaults.store.data(forKey: alarmsKey),
              let alarms = try? JSONDecoder().decode([TagAlarm].self, from: data) else {
            return []
        }
        return alarms
    }

    static func saveAlarms(_ alarms: [TagAlarm]) {
        if let data = try? JSONEncoder().encode(alarms) {
            SharedDefaults.store.set(data, forKey: alarmsKey)
        }
    }

    // MARK: - Editing

    func save(_ alarm: TagAlarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
        } else {
            alarms.append(alarm)
        }
        alarms.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        Self.saveAlarms(alarms)

        if #available(iOS 26.1, *) {
            Task { await reschedule(alarm) }
        }
    }

    func delete(_ alarm: TagAlarm) {
        alarms.removeAll { $0.id == alarm.id }
        Self.saveAlarms(alarms)

        if #available(iOS 26.1, *) {
            try? AlarmManager.shared.cancel(id: alarm.id)
        }
    }

    // MARK: - Dismissal

    // Called after a successful tag scan (and, for bedtime, once the phone is blocked)
    func endSession() {
        if #available(iOS 26.1, *) {
            Self.finish(AlarmSession.load())
        } else {
            AlarmSession.clear()
        }
        alarms = Self.loadAlarms()
        activeKind = nil
    }

    // MARK: - AlarmKit

    @available(iOS 26.1, *)
    func requestAuthorization() async {
        let state = try? await AlarmManager.shared.requestAuthorization()
        await MainActor.run {
            self.isAuthorized = state == .authorized
        }
    }

    @available(iOS 26.1, *)
    private func reschedule(_ alarm: TagAlarm) async {
        try? AlarmManager.shared.cancel(id: alarm.id)
        guard alarm.isEnabled else { return }

        if AlarmManager.shared.authorizationState != .authorized {
            await requestAuthorization()
        }

        let weekdays = alarm.weekdays.sorted().compactMap(Self.localeWeekday)
        let schedule = Alarm.Schedule.relative(.init(
            time: .init(hour: alarm.hour, minute: alarm.minute),
            repeats: weekdays.isEmpty ? .never : .weekly(weekdays)
        ))

        do {
            _ = try await AlarmManager.shared.schedule(
                id: alarm.id,
                configuration: Self.configuration(kind: alarm.kind, id: alarm.id, schedule: schedule)
            )
        } catch {
            NSLog("Failed to schedule alarm: \(error)")
        }
    }

    @available(iOS 26.1, *)
    private func observeAlarms() {
        Task { @MainActor [weak self] in
            for await scheduled in AlarmManager.shared.alarmUpdates {
                self?.refresh(from: scheduled)
            }
        }
    }

    @available(iOS 26.1, *)
    private func refresh(from scheduled: [Alarm]) {
        let ours = Set(alarms.map(\.id))
        var session = AlarmSession.load()

        // An alarm is ringing that we haven't recorded yet, e.g. the app was opened directly
        if session == nil,
           let ringing = scheduled.first(where: { $0.state == .alerting && ours.contains($0.id) }),
           let alarm = alarms.first(where: { $0.id == ringing.id }) {
            session = AlarmSession(kind: alarm.kind, parentID: alarm.id)
            session?.save()
        }

        // Drop a session with nothing ringing or pending, after a grace period so we don't
        // race an intent that is about to schedule the next follow-up
        if let current = session {
            let stillActive = scheduled.contains { alarm in
                current.contains(alarm.id) && (alarm.state == .alerting || current.followUpIDs.contains(alarm.id))
            }
            if !stillActive && Date().timeIntervalSince(current.updatedAt) > 60 {
                AlarmSession.clear()
                session = nil
            }
        }

        activeKind = session?.kind
    }

    @available(iOS 26.1, *)
    static func configuration(kind: TagAlarm.Kind, id: UUID, schedule: Alarm.Schedule) -> AlarmManager.AlarmConfiguration<TagAlarmMetadata> {
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: kind.alertTitle),
            secondaryButton: AlarmButton(text: "Scan Tag", textColor: .white, systemImageName: "wave.3.right"),
            secondaryButtonBehavior: .custom
        )
        let attributes = AlarmAttributes<TagAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert, countdown: nil, paused: nil),
            metadata: TagAlarmMetadata(kind: kind),
            tintColor: kind == .wakeUp ? .orange : .indigo
        )
        return .alarm(
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopTagAlarmIntent(alarmID: id.uuidString),
            secondaryIntent: ScanTagAlarmIntent(alarmID: id.uuidString),
            sound: .default
        )
    }

    // The alarm was silenced without a tag scan, so ring again shortly
    @available(iOS 26.1, *)
    static func handleUnscannedDismiss(alarmID: UUID) async {
        var session = AlarmSession.load()
        if session?.contains(alarmID) != true {
            guard let alarm = loadAlarms().first(where: { $0.id == alarmID }) else { return }
            session = AlarmSession(kind: alarm.kind, parentID: alarm.id)
        }
        guard var current = session else { return }

        // Bedtime is satisfied once the phone is blocked
        let isBlocked = SharedDefaults.store.bool(forKey: "isBlocking") || !ScheduleStore.activeIDs().isEmpty
        if current.kind == .bedtime && isBlocked {
            finish(current)
            return
        }
        guard current.followUpCount < maxFollowUps else {
            finish(current)
            return
        }

        let followUpID = UUID()
        do {
            _ = try await AlarmManager.shared.schedule(
                id: followUpID,
                configuration: configuration(
                    kind: current.kind,
                    id: followUpID,
                    schedule: .fixed(Date().addingTimeInterval(followUpDelay))
                )
            )
            current.followUpIDs.append(followUpID)
            current.followUpCount += 1
            current.updatedAt = Date()
            current.save()
        } catch {
            NSLog("Failed to schedule follow-up alarm: \(error)")
        }
    }

    @available(iOS 26.1, *)
    private static func finish(_ session: AlarmSession?) {
        AlarmSession.clear()
        guard let session = session else { return }

        // Stop (not cancel) the parent so a repeating alarm still rings next time
        try? AlarmManager.shared.stop(id: session.parentID)
        for id in session.followUpIDs {
            try? AlarmManager.shared.cancel(id: id)
        }

        // A one-off alarm is spent once dismissed
        var alarms = loadAlarms()
        if let index = alarms.firstIndex(where: { $0.id == session.parentID }), alarms[index].weekdays.isEmpty {
            alarms[index].isEnabled = false
            saveAlarms(alarms)
        }
    }

    @available(iOS 26.1, *)
    private static func localeWeekday(_ weekday: Int) -> Locale.Weekday? {
        switch weekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }
}

// MARK: - Intents

@available(iOS 26.1, *)
struct StopTagAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Alarm"
    static var isDiscoverable = false

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() {}

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            await TagAlarmManager.handleUnscannedDismiss(alarmID: id)
        }
        return .result()
    }
}

@available(iOS 26.1, *)
struct ScanTagAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Scan Tag"
    static var isDiscoverable = false
    static var openAppWhenRun = true

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() {}

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        // Opening the app may silence the alarm, so keep a follow-up queued until the scan succeeds
        if let id = UUID(uuidString: alarmID) {
            await TagAlarmManager.handleUnscannedDismiss(alarmID: id)
        }
        return .result()
    }
}
