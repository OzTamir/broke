//
//  BrockerView.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//
import SwiftUI

struct BrokerView: View {
    @ObservedObject var appBlocker: AppBlocker
    @ObservedObject var nfcReader: NFCReader
    @State private var showWrongTagAlert = false
    public var tagPhrase: String
    
    var body: some View {
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
        .alert(isPresented: $showWrongTagAlert) {
            Alert(
                title: Text("Not a Broker Tag"),
                message: Text("You can overwrite this tag into a Broker tag in the settings page"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
