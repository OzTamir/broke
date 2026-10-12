//
//  SchedulesView.swift
//  Broke
//
//  Recurring blocks applied by the BrokeMonitor extension. A scheduled block can only be
//  ended early with the tag (or an emergency unblock), like a manual one.
//

import SwiftUI
import DeviceActivity
import ManagedSettings

class ScheduleManager: ObservableObject {
    static let shared = ScheduleManager()
    // DeviceActivity only lets an app monitor a limited number of activities
    static let maxSchedules = 20
    static let minimumMinutes = 15

    @Published var schedules: [BlockSchedule] = []
    @Published var activeIDs: Set<UUID> = []

    private let center = DeviceActivityCenter()

    init() {
        refresh()
    }

    // The extension changes the active set in the background, so re-read when the app comes forward
    func refresh() {
        schedules = ScheduleStore.load()
        activeIDs = ScheduleStore.activeIDs()
    }

    func activeSchedules() -> [BlockSchedule] {
        schedules.filter { activeIDs.contains($0.id) }
    }

    // Returns an error message if the schedule couldn't be registered
    func save(_ schedule: BlockSchedule) -> String? {
        guard schedule.durationMinutes >= Self.minimumMinutes else {
            return "A schedule needs to be at least \(Self.minimumMinutes) minutes long."
        }

        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
        } else {
            guard schedules.count < Self.maxSchedules else {
                return "You can have up to \(Self.maxSchedules) schedules."
            }
            schedules.append(schedule)
        }
        schedules.sort { ($0.startHour, $0.startMinute) < ($1.startHour, $1.startMinute) }
        ScheduleStore.save(schedules)

        do {
            try monitor(schedule)
        } catch {
            NSLog("Failed to monitor schedule: \(error)")
            return "iOS wouldn't accept this schedule: \(error.localizedDescription)"
        }
        // Starting to monitor during the window applies it straight away
        activeIDs = ScheduleStore.activeIDs()
        return nil
    }

    func delete(_ schedule: BlockSchedule) {
        center.stopMonitoring([DeviceActivityName(schedule.activityName)])
        schedules.removeAll { $0.id == schedule.id }
        ScheduleStore.save(schedules)
    }

    func endActiveEarly(reason: BlockSession.EndReason) {
        for id in ScheduleStore.activeIDs() {
            Shields.clear(ScheduleStore.managedStore(for: id))
            ScheduleStore.setActive(id, false)
            StatsStore.end(.schedule, scheduleID: id, reason: reason)
        }
        activeIDs = []
    }

    private func monitor(_ schedule: BlockSchedule) throws {
        let name = DeviceActivityName(schedule.activityName)
        center.stopMonitoring([name])
        guard schedule.isEnabled else { return }

        // Repeats daily; the extension skips days that aren't selected
        let activitySchedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: schedule.startHour, minute: schedule.startMinute),
            intervalEnd: DateComponents(hour: schedule.endHour, minute: schedule.endMinute),
            repeats: true
        )
        try center.startMonitoring(name, during: activitySchedule)
    }
}

struct SchedulesView: View {
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject private var profileManager: ProfileManager
    @EnvironmentObject private var appBlocker: AppBlocker
    @Environment(\.dismiss) private var dismiss
    @State private var editingSchedule: BlockSchedule?

    // Editing a schedule mid-block would be an easy way out of it
    private var isLocked: Bool {
        appBlocker.isBlocking || !scheduleManager.activeIDs.isEmpty
    }

    var body: some View {
        NavigationView {
            List {
                if isLocked {
                    Label("Schedules can't be changed while a block is active.", systemImage: "lock.fill")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else if scheduleManager.schedules.isEmpty {
                    Text("Block apps automatically at set times, like during work or overnight. A scheduled block can only be ended early with your tag.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                ForEach(scheduleManager.schedules) { schedule in
                    ScheduleRow(
                        schedule: schedule,
                        profileName: profileManager.profiles.first { $0.id == schedule.profileID }?.name ?? "Deleted profile",
                        isActive: scheduleManager.activeIDs.contains(schedule.id),
                        isLocked: isLocked
                    ) { isEnabled in
                        var updated = schedule
                        updated.isEnabled = isEnabled
                        _ = scheduleManager.save(updated)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isLocked { editingSchedule = schedule }
                    }
                }
                .onDelete { offsets in
                    guard !isLocked else { return }
                    offsets.map { scheduleManager.schedules[$0] }.forEach(scheduleManager.delete)
                }
                .deleteDisabled(isLocked)
            }
            .navigationTitle("Schedules")
            .navigationBarItems(
                leading: Button("Done") { dismiss() },
                trailing: Button(action: {
                    editingSchedule = BlockSchedule(
                        name: "Work",
                        profileID: profileManager.currentProfile.id,
                        startHour: 9, startMinute: 0, endHour: 17, endMinute: 0,
                        weekdays: [2, 3, 4, 5, 6]
                    )
                }) {
                    Image(systemName: "plus")
                }
                .disabled(isLocked)
            )
            .sheet(item: $editingSchedule) { schedule in
                ScheduleFormView(
                    schedule: schedule,
                    isNew: !scheduleManager.schedules.contains { $0.id == schedule.id },
                    profiles: profileManager.profiles,
                    onSave: { scheduleManager.save($0) },
                    onDelete: { scheduleManager.delete($0) }
                )
            }
        }
    }
}

struct ScheduleRow: View {
    let schedule: BlockSchedule
    let profileName: String
    let isActive: Bool
    let isLocked: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(schedule.name)
                        .font(.headline)
                    if isActive {
                        Text("ACTIVE")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                    }
                }
                Text("\(clockString(schedule.startHour, schedule.startMinute)) – \(clockString(schedule.endHour, schedule.endMinute))")
                    .font(.title3)
                Text("\(profileName) · \(weekdaySummary(schedule.weekdays, emptyLabel: "Every day"))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { schedule.isEnabled }, set: onToggle))
                .labelsHidden()
                .disabled(isLocked)
        }
        .opacity(schedule.isEnabled ? 1 : 0.5)
    }
}

struct ScheduleFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var schedule: BlockSchedule
    @State private var start: Date
    @State private var end: Date
    @State private var errorMessage: String?
    let isNew: Bool
    let profiles: [Profile]
    let onSave: (BlockSchedule) -> String?
    let onDelete: (BlockSchedule) -> Void

    init(schedule: BlockSchedule, isNew: Bool, profiles: [Profile], onSave: @escaping (BlockSchedule) -> String?, onDelete: @escaping (BlockSchedule) -> Void) {
        _schedule = State(initialValue: schedule)
        _start = State(initialValue: clockDate(schedule.startHour, schedule.startMinute))
        _end = State(initialValue: clockDate(schedule.endHour, schedule.endMinute))
        self.isNew = isNew
        self.profiles = profiles
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Name")) {
                    TextField("Name", text: $schedule.name)
                }

                Section(header: Text("Time"), footer: Text("If the end is before the start, the block runs overnight.")) {
                    DatePicker("Starts", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $end, displayedComponents: .hourAndMinute)
                }

                Section(header: Text("Profile")) {
                    Picker("Block", selection: $schedule.profileID) {
                        ForEach(profiles) { profile in
                            Label(profile.name, systemImage: profile.icon).tag(profile.id)
                        }
                    }
                }

                Section(header: Text("Repeat"), footer: Text(schedule.weekdays.isEmpty ? "Every day." : "")) {
                    WeekdayPicker(weekdays: $schedule.weekdays)
                }

                if !isNew {
                    Section {
                        Button("Delete Schedule", role: .destructive) {
                            onDelete(schedule)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Add Schedule" : "Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save", action: save)
                    .disabled(schedule.name.isEmpty)
            )
            .alert(item: Binding(get: { errorMessage.map(IdentifiedMessage.init) }, set: { errorMessage = $0?.text })) { message in
                Alert(title: Text("Couldn't Save Schedule"), message: Text(message.text), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func save() {
        let startComponents = Calendar.current.dateComponents([.hour, .minute], from: start)
        let endComponents = Calendar.current.dateComponents([.hour, .minute], from: end)
        schedule.startHour = startComponents.hour ?? 0
        schedule.startMinute = startComponents.minute ?? 0
        schedule.endHour = endComponents.hour ?? 0
        schedule.endMinute = endComponents.minute ?? 0
        schedule.isEnabled = true

        if let error = onSave(schedule) {
            errorMessage = error
        } else {
            dismiss()
        }
    }
}

struct IdentifiedMessage: Identifiable {
    let text: String
    var id: String { text }
}

// Weekday toggles starting from the user's first day of the week
struct WeekdayPicker: View {
    @Binding var weekdays: Set<Int>

    var body: some View {
        HStack {
            ForEach(orderedWeekdays(), id: \.self) { weekday in
                let isOn = weekdays.contains(weekday)
                Button(Calendar.current.veryShortWeekdaySymbols[weekday - 1]) {
                    if isOn {
                        weekdays.remove(weekday)
                    } else {
                        weekdays.insert(weekday)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 34, height: 34)
                .background(Circle().fill(isOn ? Color.accentColor : Color.secondary.opacity(0.15)))
                .foregroundColor(isOn ? .white : .primary)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func orderedWeekdays() -> [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }
}

func clockDate(_ hour: Int, _ minute: Int) -> Date {
    Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
}

func clockString(_ hour: Int, _ minute: Int) -> String {
    clockDate(hour, minute).formatted(date: .omitted, time: .shortened)
}

func weekdaySummary(_ weekdays: Set<Int>, emptyLabel: String) -> String {
    if weekdays.isEmpty { return emptyLabel }
    if weekdays == Set(1...7) { return "Every day" }
    if weekdays == [2, 3, 4, 5, 6] { return "Weekdays" }
    if weekdays == [1, 7] { return "Weekends" }

    let symbols = Calendar.current.shortWeekdaySymbols
    return weekdays.sorted().map { symbols[$0 - 1] }.joined(separator: " ")
}
