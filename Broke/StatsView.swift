//
//  StatsView.swift
//  Broke
//

import SwiftUI

struct DayTotal: Identifiable {
    let date: Date
    let time: TimeInterval
    var id: Date { date }
}

struct BlockStats {
    // Blocked time needed for a day to count towards the streak
    static let streakMinimum: TimeInterval = 30 * 60

    let sessions: [BlockSession]
    private let calendar = Calendar.current

    init(sessions: [BlockSession]) {
        self.sessions = sessions
    }

    // Overlapping manual and scheduled blocks are merged so time isn't counted twice
    private func mergedIntervals(now: Date = Date()) -> [DateInterval] {
        let intervals = sessions
            .map { DateInterval(start: $0.start, end: max($0.start, $0.end ?? now)) }
            .sorted { $0.start < $1.start }

        var merged: [DateInterval] = []
        for interval in intervals {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    func blockedTime(in range: DateInterval) -> TimeInterval {
        mergedIntervals().reduce(0) { total, interval in
            total + (interval.intersection(with: range)?.duration ?? 0)
        }
    }

    func blockedTime(onDayContaining date: Date) -> TimeInterval {
        guard let day = calendar.dateInterval(of: .day, for: date) else { return 0 }
        return blockedTime(in: day)
    }

    func blockedTimeThisWeek() -> TimeInterval {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return blockedTime(in: week)
    }

    func breaks(onDayContaining date: Date) -> Int {
        sessions.filter { session in
            guard session.isBreak, let end = session.end else { return false }
            return calendar.isDate(end, inSameDayAs: date)
        }.count
    }

    private func qualifies(_ date: Date) -> Bool {
        blockedTime(onDayContaining: date) >= Self.streakMinimum && breaks(onDayContaining: date) == 0
    }

    // Consecutive qualifying days, counting today only once it qualifies
    func currentStreak() -> Int {
        var day = Date()
        if !qualifies(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while qualifies(day), streak < 3650 {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    func longestStreak() -> Int {
        guard let first = sessions.map(\.start).min() else { return 0 }

        var longest = 0
        var current = 0
        var day = calendar.startOfDay(for: first)
        let today = calendar.startOfDay(for: Date())
        while day <= today {
            current = qualifies(day) ? current + 1 : 0
            longest = max(longest, current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return longest
    }

    // Blocked time for each of the last seven days, oldest first
    func lastSevenDays() -> [DayTotal] {
        (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return DayTotal(date: date, time: blockedTime(onDayContaining: date))
        }
    }
}

struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appBlocker: AppBlocker
    @State private var stats = BlockStats(sessions: StatsStore.load())

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        StatTile(title: "Today", value: durationString(stats.blockedTime(onDayContaining: Date())))
                        StatTile(title: "This week", value: durationString(stats.blockedTimeThisWeek()))
                    }
                    HStack {
                        StatTile(title: "Streak", value: dayCount(stats.currentStreak()))
                        StatTile(title: "Best streak", value: dayCount(stats.longestStreak()))
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section(header: Text("Last 7 days"), footer: Text("A day counts towards your streak with at least 30 minutes blocked and no emergency unblocks.")) {
                    WeekBars(days: stats.lastSevenDays())
                        .frame(height: 140)
                        .padding(.vertical, 8)
                }

                Section(header: Text("Emergency unblocks")) {
                    HStack {
                        Text("Remaining")
                        Spacer()
                        Text("\(appBlocker.emergencyUnblocksRemaining) of \(AppBlocker.maxEmergencyUnblocks)")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Recent blocks")) {
                    if stats.sessions.isEmpty {
                        Text("No blocks yet. Tap your tag to start one.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(stats.sessions.suffix(20).reversed()) { session in
                        SessionRow(session: session)
                    }
                }
            }
            .navigationTitle("Stats")
            .navigationBarItems(leading: Button("Done") { dismiss() })
            .onAppear {
                stats = BlockStats(sessions: StatsStore.load())
            }
        }
    }

    private func dayCount(_ days: Int) -> String {
        days == 1 ? "1 day" : "\(days) days"
    }
}

struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }
}

struct WeekBars: View {
    let days: [DayTotal]

    var body: some View {
        let maxTime = max(days.map(\.time).max() ?? 0, 60 * 60)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(days) { day in
                VStack(spacing: 4) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(day.time >= BlockStats.streakMinimum ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: max(2, 100 * day.time / maxTime))
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide))): \(durationString(day.time))")
            }
        }
    }
}

struct SessionRow: View {
    let session: BlockSession

    var body: some View {
        HStack {
            Image(systemName: session.source == .schedule ? "calendar" : "wave.3.right")
                .foregroundColor(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.start.formatted(date: .abbreviated, time: .shortened))
                Text(endDescription)
                    .font(.caption)
                    .foregroundColor(session.isBreak ? .red : .secondary)
            }
            Spacer()
            Text(durationString((session.end ?? Date()).timeIntervalSince(session.start)))
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }

    private var endDescription: String {
        switch session.endReason {
        case .tag: return "Ended with tag"
        case .emergency: return "Emergency unblock"
        case .permissionRevoked: return "Screen Time access turned off"
        case .scheduleEnded: return "Schedule finished"
        case nil: return "In progress"
        }
    }
}

func durationString(_ interval: TimeInterval) -> String {
    let minutes = Int(interval / 60)
    if minutes < 60 {
        return "\(minutes)m"
    }
    return "\(minutes / 60)h \(minutes % 60)m"
}
