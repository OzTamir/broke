//
//  SettingsView.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//

import SwiftUI
import FamilyControls
import DeviceActivity

struct SettingsView: View {
    @ObservedObject var appBlocker: AppBlocker
    @ObservedObject var nfcReader: NFCReader
    @State private var showingFamilyActivityPicker = false
    @State private var activitySelection = FamilyActivitySelection()
    
    var body: some View {
        VStack(spacing: 20) {
            if appBlocker.isAuthorized {
                Button(action: {
                    NSLog("Scan NFC Tag button pressed")
                    nfcReader.scan()
                }) {
                    Text("Scan NFC Tag")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Text(nfcReader.message)
                    .padding()
                
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
