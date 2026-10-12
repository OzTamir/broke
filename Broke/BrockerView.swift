//
//  BrockerView.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//
import SwiftUI
import SFSymbolsPicker
import FamilyControls
import ManagedSettings

enum BrokerAlert: Identifiable {
    case wrongTag
    case createTag
    case tagCreated(success: Bool)
    case notAuthorized
    case emptyProfile
    case emergencyUnblock
    case permissionRevoked

    var id: String {
        switch self {
        case .wrongTag: return "wrongTag"
        case .createTag: return "createTag"
        case .tagCreated(let success): return "tagCreated-\(success)"
        case .notAuthorized: return "notAuthorized"
        case .emptyProfile: return "emptyProfile"
        case .emergencyUnblock: return "emergencyUnblock"
        case .permissionRevoked: return "permissionRevoked"
        }
    }
}

enum BrokerSheet: String, Identifiable {
    case alarms, schedules, stats, tags

    var id: String { rawValue }
}

struct BrokerView: View {
    @EnvironmentObject private var appBlocker: AppBlocker
    @EnvironmentObject private var profileManager: ProfileManager
    @EnvironmentObject private var alarmManager: TagAlarmManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @StateObject private var nfcReader = NFCReader()

    @State private var activeAlert: BrokerAlert?
    @State private var activeSheet: BrokerSheet?

    // Blocked either by the tag or by a schedule
    private var isBlocking: Bool {
        appBlocker.isBlocking || !scheduleManager.activeIDs.isEmpty
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    VStack(spacing: 0) {
                        blockOrUnblockButton(geometry: geometry)

                        if !isBlocking {
                            Divider()

                            ProfilesPicker(profileManager: profileManager)
                                .frame(height: geometry.size.height / 2)
                                .transition(.move(edge: .bottom))
                        }
                    }
                    .background(isBlocking ? Color("BlockingBackground") : Color("NonBlockingBackground"))
                }
            }
            .navigationBarItems(leading: menuButton, trailing: createTagButton)
            .alert(item: $activeAlert) { alert in
                makeAlert(alert)
            }
            .sheet(item: $activeSheet) { sheet in
                sheetView(sheet)
            }
        }
        .animation(.spring(), value: isBlocking)
        .onAppear {
            StatusNotifier.requestPermission()
        }
        .onReceive(appBlocker.$permissionRevokedWhileBlocking) { revoked in
            if revoked {
                activeAlert = .permissionRevoked
                appBlocker.permissionRevokedWhileBlocking = false
            }
        }
    }

    @ViewBuilder
    private func sheetView(_ sheet: BrokerSheet) -> some View {
        switch sheet {
        case .alarms:
            AlarmsView()
                .environmentObject(alarmManager)
        case .schedules:
            SchedulesView()
                .environmentObject(scheduleManager)
                .environmentObject(profileManager)
                .environmentObject(appBlocker)
        case .stats:
            StatsView()
                .environmentObject(appBlocker)
        case .tags:
            TagSettingsView()
                .environmentObject(appBlocker)
                .environmentObject(scheduleManager)
        }
    }

    private func makeAlert(_ alert: BrokerAlert) -> Alert {
        switch alert {
        case .wrongTag:
            return Alert(
                title: Text("Not a Broker Tag"),
                message: Text("This tag isn't paired with this phone. You can create a new Broker tag using the + button."),
                dismissButton: .default(Text("OK"))
            )
        case .createTag:
            return Alert(
                title: Text("Create Broker Tag"),
                message: Text("Do you want to create a new Broker tag?"),
                primaryButton: .default(Text("Create")) { createBrokerTag() },
                secondaryButton: .cancel()
            )
        case .tagCreated(let success):
            return Alert(
                title: Text("Tag Creation"),
                message: Text(success ? "Broker tag created successfully!" : "Failed to create Broker tag. Please try again."),
                dismissButton: .default(Text("OK"))
            )
        case .notAuthorized:
            return Alert(
                title: Text("Screen Time Access Needed"),
                message: Text("Broke needs Screen Time permission to block apps."),
                primaryButton: .default(Text("Grant Access")) {
                    Task { await appBlocker.requestAuthorization() }
                },
                secondaryButton: .cancel()
            )
        case .emptyProfile:
            return Alert(
                title: Text("Nothing to Block"),
                message: Text("The \"\(profileManager.currentProfile.name)\" profile has no apps, categories or websites. Long-press it to edit."),
                dismissButton: .default(Text("OK"))
            )
        case .emergencyUnblock:
            return Alert(
                title: Text("Emergency Unblock"),
                message: Text("This unblocks without your tag, including any scheduled block. You have \(appBlocker.emergencyUnblocksRemaining) left and they don't come back."),
                primaryButton: .destructive(Text("Unblock")) {
                    withAnimation(.spring()) {
                        appBlocker.emergencyUnblock()
                    }
                },
                secondaryButton: .cancel()
            )
        case .permissionRevoked:
            return Alert(
                title: Text("Block Broken"),
                message: Text("Screen Time access was turned off, which removed your block. It's been recorded in your stats."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private func blockOrUnblockButton(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            if let kind = alarmManager.activeKind {
                StatusBadge(
                    text: kind == .wakeUp ? "Wake-up alarm" : "Bedtime alarm",
                    icon: kind.icon,
                    color: kind == .wakeUp ? .orange : .indigo
                )
            } else if !appBlocker.isBlocking, let schedule = scheduleManager.activeSchedules().first {
                StatusBadge(
                    text: "\(schedule.name) until \(clockString(schedule.endHour, schedule.endMinute))",
                    icon: "calendar",
                    color: .red
                )
            }

            Text(scanCaption)
                .font(.caption)
                .opacity(0.75)
                .transition(.scale)

            Button(action: {
                withAnimation(.spring()) {
                    scanTag()
                }
            }) {
                Image(isBlocking ? "RedIcon" : "GreenIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    // Shrinks to leave room for the badge, caption and buttons around it
                    .frame(maxHeight: geometry.size.height / 3)
            }
            .layoutPriority(-1)
            .transition(.scale)

            if isBlocking && appBlocker.emergencyUnblocksRemaining > 0 {
                Button("Emergency unblock (\(appBlocker.emergencyUnblocksRemaining) left)") {
                    activeAlert = .emergencyUnblock
                }
                .font(.caption)
                .opacity(0.6)
                .padding(.top, 24)
            }

            #if DEBUG
            // Lets the full flow be tested without a physical tag; never in release builds
            Button("Simulate tag scan") {
                withAnimation(.spring()) {
                    scanTag(simulated: true)
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .padding(.top, 12)
            #endif
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: isBlocking ? geometry.size.height : geometry.size.height / 2)
        .animation(.spring(), value: isBlocking)
    }

    private var scanCaption: String {
        switch alarmManager.activeKind {
        case .wakeUp:
            return "Tap and scan your tag to stop the alarm"
        case .bedtime:
            return isBlocking ? "Tap and scan your tag to stop the alarm" : "Brick your phone to stop the alarm"
        case nil:
            if appBlocker.isBlocking {
                return "Tap to unblock"
            }
            return isBlocking ? "Tap to end the scheduled block early" : "Tap to block"
        }
    }

    // simulated: skip NFC and act as if a paired tag was scanned (debug builds only)
    private func scanTag(simulated: Bool = false) {
        let action: TagAction
        switch TagActions.plan() {
        case .success(let planned):
            action = planned
        case .failure(.notAuthorized):
            activeAlert = .notAuthorized
            return
        case .failure(.emptyProfile):
            activeAlert = .emptyProfile
            return
        }

        if simulated {
            TagActions.perform(action)
            return
        }

        nfcReader.scan { scan in
            guard TagSecurity.isValid(scan) else {
                activeAlert = .wrongTag
                NSLog("Wrong Tag! Payload: \(scan.text ?? "none"), ID: \(scan.tagID)")
                return
            }
            withAnimation(.spring()) {
                _ = TagActions.perform(action)
            }
        }
    }

    private var menuButton: some View {
        Menu {
            if TagAlarmManager.isSupported {
                Button(action: { activeSheet = .alarms }) {
                    Label("Alarms", systemImage: "alarm")
                }
            }
            Button(action: { activeSheet = .schedules }) {
                Label("Schedules", systemImage: "calendar")
            }
            Button(action: { activeSheet = .stats }) {
                Label("Stats", systemImage: "chart.bar")
            }
            Button(action: { activeSheet = .tags }) {
                Label("Tags & Shortcut", systemImage: "wave.3.right")
            }
        } label: {
            Image(systemName: "line.3.horizontal")
        }
    }

    private var createTagButton: some View {
        Button(action: {
            activeAlert = .createTag
        }) {
            Image(systemName: "plus")
        }
        // While blocking, pairing a fresh tag would be a way to unblock without the real one
        .disabled(isBlocking || !NFCReader.isAvailable)
    }

    private func createBrokerTag() {
        nfcReader.write(TagSecurity.phrase) { tagID in
            if let tagID = tagID {
                TagSecurity.pair(tagID)
            }
            activeAlert = .tagCreated(success: tagID != nil)
        }
    }
}

struct StatusBadge: View {
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        Label(text, systemImage: icon)
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(color))
            .padding(.bottom, 8)
    }
}
