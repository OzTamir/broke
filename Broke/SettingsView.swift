//
//  SettingsView.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//

import SwiftUI
import FamilyControls
import DeviceActivity
import CoreNFC

struct SettingsView: View {
    @ObservedObject var appBlocker: AppBlocker
    @State private var showingFamilyActivityPicker = false
    @State private var activitySelection: FamilyActivitySelection
    
    init(appBlocker: AppBlocker) {
        self.appBlocker = appBlocker
        
        var selection = FamilyActivitySelection()
        selection.applicationTokens = appBlocker.appTokens
        selection.categoryTokens = appBlocker.categoryTokens
        _activitySelection = State(initialValue: selection)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if appBlocker.isAuthorized {
                VStack(spacing: 5) {
                    Text("Blocked apps: \(appBlocker.appTokens.count)")
                    Text("Blocked categories: \(appBlocker.categoryTokens.count)")
                }
                Button(action: {
                    showingFamilyActivityPicker = true
                }) {
                    Text("Configure Blocked Apps")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            } else {
                Text("Authorization required")
                    .foregroundColor(.red)
                Button(action: {
                    Task {
                        await appBlocker.requestAuthorization()
                    }
                }) {
                    Text("Request Authorization")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
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
    }
    
    private func handleSelectedActivities() {
        appBlocker.appTokens = activitySelection.applicationTokens
        appBlocker.categoryTokens = activitySelection.categoryTokens
    }
}
