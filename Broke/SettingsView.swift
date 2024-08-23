//
//  SettingsView.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//

import SwiftUI
import FamilyControls
import SFSymbolsPicker

struct SettingsView: View {
    @ObservedObject var appBlocker: AppBlocker
    @ObservedObject var profileManager: ProfileManager
    @State private var editedName: String = ""
    @State private var editedIcon: String = ""
    @State private var showingDeleteAlert = false
    @State private var showingFamilyActivityPicker = false
    @State private var showingNameEdit = false
    @State private var showingIconPicker = false
    @State private var activitySelection: FamilyActivitySelection
    
    init(appBlocker: AppBlocker, profileManager: ProfileManager) {
        self.appBlocker = appBlocker
        self.profileManager = profileManager
        
        var selection = FamilyActivitySelection()
        selection.applicationTokens = profileManager.currentProfile.appTokens
        selection.categoryTokens = profileManager.currentProfile.categoryTokens
        _activitySelection = State(initialValue: selection)
    }
    
    private var isNameValid: Bool {
        !editedName.isEmpty && (editedName == profileManager.currentProfile.name || 
            !profileManager.profiles.contains { $0.name == editedName })
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text(profileManager.currentProfile.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: { showingNameEdit = true }) {
                        Image(systemName: "pencil")
                    }
                    
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .listRowBackground(Color.clear)
            
            Section(header: Text("Profile Icon")) {
                HStack {
                    Image(systemName: editedIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                    
                    Button("Change Icon") {
                        showingIconPicker = true
                    }
                }
            }
            
            Section(header: Text("Blocked Content")) {
                HStack {
                    Text("Blocked apps")
                    Spacer()
                    Text("\(profileManager.currentProfile.appTokens.count)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Blocked categories")
                    Spacer()
                    Text("\(profileManager.currentProfile.categoryTokens.count)")
                        .foregroundColor(.secondary)
                }
                
                Button("Configure Blocked Apps") {
                    showingFamilyActivityPicker = true
                }
                .disabled(appBlocker.isBlocking)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: updateViewFromCurrentProfile)
        .onChange(of: profileManager.currentProfileId) { _ in
            updateViewFromCurrentProfile()
        }
        .sheet(isPresented: $showingIconPicker) {
            SymbolsPicker(selection: $editedIcon, title: "Pick a symbol", autoDismiss: true)
        }
        .onChange(of: showingIconPicker) { isPresented in
            if !isPresented {
                saveChanges()
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
        .alert("Rename Profile", isPresented: $showingNameEdit) {
            TextField("Profile Name", text: $editedName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if isNameValid {
                    saveChanges()
                }
            }
        } message: {
            if !isNameValid && !editedName.isEmpty {
                Text("This name is already in use")
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Profile"),
                message: Text("Are you sure you want to delete this profile?"),
                primaryButton: .destructive(Text("Delete")) {
                    deleteProfile()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func updateViewFromCurrentProfile() {
        editedName = profileManager.currentProfile.name
        editedIcon = profileManager.currentProfile.icon
    }
    
    private func saveChanges() {
        profileManager.updateCurrentProfile(name: editedName, iconName: editedIcon)
    }
    
    private func deleteProfile() {
        profileManager.deleteCurrentProfile()
    }
    
    private func handleSelectedActivities() {
        profileManager.updateCurrentProfile(
            appTokens: activitySelection.applicationTokens,
            categoryTokens: activitySelection.categoryTokens
        )
    }
}
