//
//  AppBlocker.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//
import SwiftUI
import ManagedSettings
import FamilyControls

class AppBlocker: ObservableObject {
    static let shared = AppBlocker()
    static let maxEmergencyUnblocks = 5

    let store = ManagedSettingsStore()
    @Published var isBlocking = false
    @Published var isAuthorized = false
    @Published var emergencyUnblocksRemaining = AppBlocker.maxEmergencyUnblocks
    // Set when Screen Time access was turned off mid-block, so the UI can call it out
    @Published var permissionRevokedWhileBlocking = false

    init() {
        loadBlockingState()
        // Read the current status right away; the Shortcuts intent can run before the request below finishes
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        Task {
            await requestAuthorization()
        }
    }

    @MainActor
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            print("Failed to request authorization: \(error)")
            isAuthorized = false
        }
    }

    // When launched in the background (e.g. by the Shortcuts intent) the status starts out
    // as notDetermined and only settles a moment later, so wait for it before giving up
    @MainActor
    func ensureAuthorized() async -> Bool {
        if isAuthorized { return true }
        
        for _ in 0..<20 where AuthorizationCenter.shared.authorizationStatus == .notDetermined {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        if AuthorizationCenter.shared.authorizationStatus != .approved {
            // Re-confirming access that was already granted succeeds without a prompt
            await requestAuthorization()
        }
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved || isAuthorized
        return isAuthorized
    }
    
    func block(with profile: Profile) {
        guard isAuthorized else {
            print("Not authorized to block apps")
            return
        }

        NSLog("Blocking \(profile.appTokens.count) apps, \(profile.webDomainTokens.count) websites")
        isBlocking = true
        saveBlockingState()
        Shields.apply(profile, to: store)
        StatsStore.start(.manual)
    }

    func unblock() {
        isBlocking = false
        saveBlockingState()
        Shields.clear(store)
        StatsStore.end(.manual, reason: .tag)
    }

    // Escape hatch for a lost tag; limited so it can't replace the tag
    func emergencyUnblock() {
        guard isBlocking || !ScheduleStore.activeIDs().isEmpty, emergencyUnblocksRemaining > 0 else { return }

        emergencyUnblocksRemaining -= 1
        isBlocking = false
        saveBlockingState()
        Shields.clear(store)
        StatsStore.end(.manual, reason: .emergency)
        ScheduleManager.shared.endActiveEarly(reason: .emergency)
    }

    // Turning off Screen Time access in Settings drops every shield, which we can't prevent,
    // so at least end the block honestly and record it as a break
    func checkAuthorization() {
        let status = AuthorizationCenter.shared.authorizationStatus
        isAuthorized = status == .approved
        // Only an explicit denial counts; a transient unknown state must not end a block
        guard status == .denied, isBlocking || !ScheduleStore.activeIDs().isEmpty else { return }

        isBlocking = false
        saveBlockingState()
        StatsStore.endAll(reason: .permissionRevoked)
        for id in ScheduleStore.activeIDs() {
            ScheduleStore.setActive(id, false)
        }
        ScheduleManager.shared.refresh()
        permissionRevokedWhileBlocking = true
    }

    private func loadBlockingState() {
        isBlocking = SharedDefaults.store.bool(forKey: "isBlocking")
        if SharedDefaults.store.object(forKey: "emergencyUnblocksRemaining") != nil {
            emergencyUnblocksRemaining = SharedDefaults.store.integer(forKey: "emergencyUnblocksRemaining")
        }
    }

    private func saveBlockingState() {
        SharedDefaults.store.set(isBlocking, forKey: "isBlocking")
        SharedDefaults.store.set(emergencyUnblocksRemaining, forKey: "emergencyUnblocksRemaining")
    }
}
