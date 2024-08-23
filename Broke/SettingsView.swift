//
//  SettingsView.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//

import SwiftUI
import FamilyControls

struct SettingsView: View {
    @ObservedObject var appBlocker: AppBlocker
    @ObservedObject var profileManager: ProfileManager
    @State private var showingFamilyActivityPicker = false
    @State private var activitySelection: FamilyActivitySelection
    @State private var showingAddProfileAlert = false
    @State private var newProfileName = ""
    
    init(appBlocker: AppBlocker, profileManager: ProfileManager) {
        self.appBlocker = appBlocker
        self.profileManager = profileManager
        
        var selection = FamilyActivitySelection()
        selection.applicationTokens = profileManager.currentProfile.appTokens
        selection.categoryTokens = profileManager.currentProfile.categoryTokens
        _activitySelection = State(initialValue: selection)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if appBlocker.isAuthorized {
                profilePicker
                    .disabled(appBlocker.isBlocking)
                    .onChange(of: profileManager.currentProfileId) { _ in
                        updateActivitySelection()
                    }
                
                VStack(spacing: 5) {
                    Text("Blocked apps: \(profileManager.currentProfile.appTokens.count)")
                    Text("Blocked categories: \(profileManager.currentProfile.categoryTokens.count)")
                }
                
                Button("Configure Blocked Apps") {
                    showingFamilyActivityPicker = true
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(appBlocker.isBlocking)
                
                Button("Add New Profile") {
                    showingAddProfileAlert = true
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(appBlocker.isBlocking)
            } else {
                Button("Request Authorization") {
                    Task {
                        await appBlocker.requestAuthorization()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: $showingFamilyActivityPicker) {
            NavigationView {
                FamilyActivityPicker(selection: $activitySelection)
                    .navigationTitle("Select Apps")
                    .navigationBarItems(trailing: Button("Done") {
                        showingFamilyActivityPicker = false
                        handleSelectedActivities()
                    })
            }
        }
        .alert("New Profile", isPresented: $showingAddProfileAlert) {
            TextField("Profile Name", text: $newProfileName)
            Button("Add") { addNewProfile() }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private var profilePicker: some View {
        Picker("Select Profile", selection: $profileManager.currentProfileId) {
            ForEach(profileManager.profiles) { profile in
                Text(profile.name).tag(profile.id as UUID?)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .opacity(appBlocker.isBlocking ? 0.5 : 1)
    }
    
    private func handleSelectedActivities() {
        profileManager.updateCurrentProfile(appTokens: activitySelection.applicationTokens, categoryTokens: activitySelection.categoryTokens)
    }
    
    private func addNewProfile() {
        profileManager.addProfile(name: newProfileName)
        newProfileName = ""
    }
    
    private func updateActivitySelection() {
        activitySelection.applicationTokens = profileManager.currentProfile.appTokens
        activitySelection.categoryTokens = profileManager.currentProfile.categoryTokens
    }
}