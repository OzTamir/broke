//
//  BrockerView.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//
import SwiftUI
import CoreNFC

struct BrokerView: View {
    @ObservedObject var appBlocker: AppBlocker
    @ObservedObject var nfcReader: NFCReader
    @ObservedObject var profileManager: ProfileManager
    @State private var showWrongTagAlert = false
    @State private var showCreateTagAlert = false
    @State private var nfcWriteSuccess = false
    public var tagPhrase: String
    
    var body: some View {
        NavigationView {
            VStack {
                ZStack {
                    Circle()
                        .fill(appBlocker.isBlocking ? Color.red : Color.green)
                        .frame(width: 200, height: 200)
                        .overlay(
                            Text(appBlocker.isBlocking ? "Scan Tag to Unblock" : "Scan Tag to Block")
                                .foregroundColor(.white)
                                .font(.headline)
                        )
                        .onTapGesture {
                            nfcReader.scan { payload in
                                if payload == tagPhrase {
                                    NSLog("Toggling block")
                                    appBlocker.toggleBlocking(for: profileManager.currentProfile)
                                } else {
                                    showWrongTagAlert = true
                                    NSLog("Wrong Tag!\nPayload: \(payload)")
                                }
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                        ForEach(profileManager.profiles) { profile in
                            ProfileCell(profile: profile, isSelected: profile.id == profileManager.currentProfile.id)
                                .onTapGesture {
                                    profileManager.setCurrentProfile(id: profile.id)
                                }
                        }
                    }
                    .padding()
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarItems(trailing: createTagButton)
            .alert(isPresented: $showWrongTagAlert) {
                Alert(
                    title: Text("Not a Broker Tag"),
                    message: Text("You can create a new Broker tag using the + button"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("Create Broker Tag", isPresented: $showCreateTagAlert) {
                Button("Create") { createBrokerTag() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Do you want to create a new Broker tag?")
            }
            .alert("Tag Creation", isPresented: $nfcWriteSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(nfcWriteSuccess ? "Broker tag created successfully!" : "Failed to create Broker tag. Please try again.")
            }
        }
    }
    
    private var createTagButton: some View {
        Button(action: {
            showCreateTagAlert = true
        }) {
            Image(systemName: "plus")
        }
        .disabled(!NFCNDEFReaderSession.readingAvailable)
    }
    
    private func createBrokerTag() {
        nfcReader.write(tagPhrase) { success in
            nfcWriteSuccess = !success
            showCreateTagAlert = false
        }
    }
}

struct ProfileCell: View {
    let profile: Profile
    let isSelected: Bool

    var body: some View {
        VStack {
            Image(systemName: profile.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
            Text(profile.name)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(width: 100, height: 100)
        .background(isSelected ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.2))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}
