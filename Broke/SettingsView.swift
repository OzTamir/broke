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
    @StateObject private var nfcReader = NFCReader()
    @State private var showingFamilyActivityPicker = false
    @State private var activitySelection: FamilyActivitySelection
    @State private var nfcWriteSuccess = false
    public var tagPhrase: String
    
    init(appBlocker: AppBlocker, tagPhrase: String) {
        self.appBlocker = appBlocker
        self.tagPhrase = tagPhrase
        
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
            
            if NFCNDEFReaderSession.readingAvailable {
                Button(action: {
                    createBrokerTag()
                }) {
                    Text("Create Broker Tag")
                        .padding()
                        .background(Color.green)
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
    
    private func createBrokerTag() {
        nfcReader.write(tagPhrase) { success in
            nfcWriteSuccess = success
        }
    }
}
