//
//  DeviceActivityMonitorExtension.swift
//  BrokeMonitor
//
//  Applies and removes scheduled blocks. iOS runs this in the background at the start
//  and end of each schedule's window, even when the app isn't open.
//

import DeviceActivity
import ManagedSettings
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard let id = BlockSchedule.id(fromActivity: activity.rawValue),
              let schedule = ScheduleStore.load().first(where: { $0.id == id }),
              schedule.isEnabled,
              schedule.runs(onWeekday: Calendar.current.component(.weekday, from: Date())),
              let profile = ProfileStore.load().first(where: { $0.id == schedule.profileID }),
              !profile.isEmpty else {
            return
        }

        Shields.apply(profile, to: ScheduleStore.managedStore(for: id))
        ScheduleStore.setActive(id, true)
        StatsStore.start(.schedule, scheduleID: id)
        StatusNotifier.post(StatusMessage(title: "\(schedule.name) block started", body: "\(profile.name) until \(schedule.endTimeString)."))
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        guard let id = BlockSchedule.id(fromActivity: activity.rawValue) else { return }

        Shields.clear(ScheduleStore.managedStore(for: id))
        // Already inactive if it was ended early with the tag
        if ScheduleStore.activeIDs().contains(id) {
            ScheduleStore.setActive(id, false)
            StatsStore.end(.schedule, scheduleID: id, reason: .scheduleEnded)
            let name = ScheduleStore.load().first { $0.id == id }?.name ?? "Scheduled"
            StatusNotifier.post(StatusMessage(title: "\(name) block finished", body: "Your apps are unblocked."))
        }
    }
}
