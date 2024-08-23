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
    
    @Published var appTokens: Set<ApplicationToken> = [] {
        didSet {
            saveAppTokens()
        }
    }
    @Published var categoryTokens: Set<ActivityCategoryToken> = [] {
        didSet {
            saveCategoryTokens()
        }
    }
    
    init() {
        loadSavedData()
        Task {
            await requestAuthorization()
        }
    }
    
    private func loadSavedData() {
        appTokens = loadAppTokens()
        categoryTokens = loadCategoryTokens()
        isBlocking = UserDefaults.standard.bool(forKey: "isBlocking")
        
        // Apply saved blocking state
        applyBlockingSettings()
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
        applyBlockingSettings()
        
        // Save the blocking state
        UserDefaults.standard.set(isBlocking, forKey: "isBlocking")
    }
    
    private func applyBlockingSettings() {
        if isBlocking {
            NSLog("Blocking \(appTokens.count) apps")
            // Block specified apps and categories
            store.shield.applications = appTokens.isEmpty ? nil : appTokens
            store.shield.applicationCategories = categoryTokens.isEmpty ? ShieldSettings.ActivityCategoryPolicy.none : .specific(categoryTokens)
        } else {
            // Remove all blocks
            store.shield.applications = nil
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.none
        }
    }
    
    private func saveAppTokens() {
        if let encoded = try? JSONEncoder().encode(Array(appTokens)) {
            UserDefaults.standard.set(encoded, forKey: "appTokens")
        }
    }
    
    private func saveCategoryTokens() {
        if let encoded = try? JSONEncoder().encode(Array(categoryTokens)) {
            UserDefaults.standard.set(encoded, forKey: "categoryTokens")
        }
    }
    
    private func loadAppTokens() -> Set<ApplicationToken> {
        guard let data = UserDefaults.standard.data(forKey: "appTokens"),
              let decodedTokens = try? JSONDecoder().decode([ApplicationToken].self, from: data) else {
            return []
        }
        NSLog("Decoded size: \(decodedTokens)")
        return Set(decodedTokens)
    }
    
    private func loadCategoryTokens() -> Set<ActivityCategoryToken> {
        guard let data = UserDefaults.standard.data(forKey: "categoryTokens"),
              let decodedTokens = try? JSONDecoder().decode([ActivityCategoryToken].self, from: data) else {
            return []
        }
        return Set(decodedTokens)
    }
}
