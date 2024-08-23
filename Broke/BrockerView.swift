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
    @State private var showWrongTagAlert = false
    @State private var showCreateTagAlert = false
    @State private var nfcWriteSuccess = false
    public var tagPhrase: String
    
    var body: some View {
        NavigationView {
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
                            // Check the payload and toggle appBlocker if condition is met
                            if payload == tagPhrase {
                                NSLog("Toggling block")
                                appBlocker.toggleBlocking()
                            } else {
                                showWrongTagAlert = true
                                NSLog("Wrong Tag!\nPayload: \(payload)")
                            }
                        }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
