//
//  BrokeApp.swift
//  Broke
//
//  Created by Oz Tamir on 19/08/2024.
//

import SwiftUI

@main
struct BrokeApp: App {
    // Shared instances so the Shortcuts intent acts on the same state as the UI
    @StateObject private var appBlocker = AppBlocker.shared
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var alarmManager = TagAlarmManager.shared
    @StateObject private var scheduleManager = ScheduleManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            BrokerView()
                .environmentObject(appBlocker)
                .environmentObject(profileManager)
                .environmentObject(alarmManager)
                .environmentObject(scheduleManager)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // Schedules start and end in the extension, and Screen Time access can change in Settings
            scheduleManager.refresh()
            appBlocker.checkAuthorization()
        }
    }
}
