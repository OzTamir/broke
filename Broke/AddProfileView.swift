//
//  AddProfileView.swift
//  Broke
//
//  Created by Oz Tamir on 23/08/2024.
//

import SwiftUI
import CoreNFC
import SFSymbolsPicker
import FamilyControls
import ManagedSettings

struct AddProfileView: View {
    @State private var profileName = ""
    @State private var profileIcon = "notifications_off"
    @State private var selectedApps = Set<ApplicationToken>()
    @State private var selectedCategories = Set<ActivityCategoryToken>()
    @State private var showSymbolsPicker = false
    @State private var showAppSelection = false
    @State private var activitySelection = FamilyActivitySelection()
    let onSave: (Profile) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Profile Name", text: $profileName)
                Button(action: { showSymbolsPicker = true }) {
                    HStack {
                        Text("Choose Icon")
                        Spacer()
                        Image(systemName: profileIcon)
                    }
                }
                Button(action: { showAppSelection = true }) {
                    Text("Choose Apps and Categories to Block")
                }
            }
            .navigationTitle("Add Profile")
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel),
                trailing: Button("Save", action: handleSave)
                    .disabled(profileName.isEmpty)
            )
            .sheet(isPresented: $showSymbolsPicker) {
                SymbolsPicker(selection: $profileIcon, title: "Pick an icon", autoDismiss: true)
            }
            .sheet(isPresented: $showAppSelection) {
                NavigationView {
                    FamilyActivityPicker(selection: $activitySelection)
                        .navigationTitle("Select Apps")
                        .navigationBarItems(trailing: Button("Done") {
                            showAppSelection = false
                        })
                }
            }
        }
    }
    
    private func handleSave() {
        let newProfile = Profile(
            name: profileName,
            appTokens: activitySelection.applicationTokens,
            categoryTokens: activitySelection.categoryTokens,
            icon: profileIcon
        )
        
        onSave(newProfile)
    }
}