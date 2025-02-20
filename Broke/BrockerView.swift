//
//  BrockerView.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//
import SwiftUI
import CoreNFC
import SFSymbolsPicker
import FamilyControls
import ManagedSettings

struct BrokerView: View {
    @EnvironmentObject private var appBlocker: AppBlocker
    @EnvironmentObject private var profileManager: ProfileManager
    @EnvironmentObject private var attendanceManager: AttendanceManager
    @StateObject private var nfcReader = NFCReader()
    private let tagPhrase = "BROKE-IS-GREAT"
    
    @State private var showWrongTagAlert = false
    @State private var showCreateTagAlert = false
    @State private var nfcWriteSuccess = false
    @State private var showAttendanceRecords = false

    
    // New state for the attendance message.
    @State private var attendanceMessage: String?
    
    private var isBlocking : Bool {
        get {
            return appBlocker.isBlocking
        }
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    VStack(spacing: 0) {
                        blockOrUnblockButton(geometry: geometry)
                        
                        if !isBlocking {
                            Divider()
                            
                            ProfilesPicker(profileManager: profileManager)
                                .frame(height: geometry.size.height / 2)
                                .transition(.move(edge: .bottom))
                        }
                    }
                    .background(isBlocking ? Color("BlockingBackground") : Color("NonBlockingBackground"))
                    
                    // Attendance message overlay
                    if let message = attendanceMessage {
                        Text(message)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .transition(.opacity)
                    }
                }
                .navigationBarItems(
                    leading: Button(action: {
                        showAttendanceRecords = true
                    }) {
                        Image(systemName: "person.3.fill")
                    },
                    trailing: createTagButton
                )
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
            .animation(.spring(), value: isBlocking)
            .sheet(isPresented: $showAttendanceRecords) {
                AttendanceRecordsView()
                    .environmentObject(attendanceManager)
            }
        }
    }
    
    @ViewBuilder
    private func blockOrUnblockButton(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            Text(isBlocking ? "Tap to unblock" : "Tap to block")
                .font(.caption)
                .opacity(0.75)
                .transition(.scale)
            
            Button(action: {
                withAnimation(.spring()) {
                    scanTag()
                }
            }) {
                Image(isBlocking ? "RedIcon" : "GreenIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: geometry.size.height / 3)
            }
            .transition(.scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: isBlocking ? geometry.size.height : geometry.size.height / 2)
        .animation(.spring(), value: isBlocking)
    }
    
    private func scanTag() {
        nfcReader.scan { payload in
            if payload == tagPhrase {
                // Determine the current blocking state before toggling.
                let currentlyBlocking = appBlocker.isBlocking
                
                // Toggle the blocking state.
                appBlocker.toggleBlocking(for: profileManager.currentProfile)
                
                if currentlyBlocking == false {
                    // We were not blocking before, so now we are turning on blocking.
                    // Log attendance and show the attendance logged message.
                    attendanceManager.logAttendance(for: profileManager.currentProfile)
                    showAttendance("Your attendance has been logged!")
                } else {
                    // We were blocking before, so toggling off means class is over.
                    showAttendance("Class is over")
                }
            } else {
                showWrongTagAlert = true
                NSLog("Wrong Tag! Payload: \(payload)")
            }
        }
    }
    
    private func showAttendance(_ message: String) {
        withAnimation {
            attendanceMessage = message
        }
        // Remove the message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                attendanceMessage = nil
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
