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
    let store = ManagedSettingsStore()
    @Published var isBlocking = false
    @Published var isAuthorized = false
    
    // Add variables for app and category tokens
    @Published var appTokens: Set<ApplicationToken> = []
    @Published var categoryTokens: Set<ActivityCategoryToken> = []
    
    init() {
        Task {
            print("Hello")
            await requestAuthorization()
        }
    }
    
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
        } catch {
            print("Failed to request authorization: \(error)")
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        }
    }
    
    func toggleBlocking() {
        guard isAuthorized else {
            print("Not authorized to block apps")
            return
        }
        
        isBlocking.toggle()
        if isBlocking {
            // Block only specified apps and categories
            store.shield.applications = appTokens
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(categoryTokens)
        } else {
            // Remove all blocks
            store.shield.applications = []
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.none
        }
    }
}
