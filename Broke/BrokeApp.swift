//
//  BrokeApp.swift
//  Broke
//
//  Created by Oz Tamir on 19/08/2024.
//

import SwiftUI

@main
struct BrokeApp: App {
    @StateObject private var appBlocker = AppBlocker()
    @StateObject private var profileManager = ProfileManager()
    
    var body: some Scene {
        WindowGroup {
            BrokerView()
                .environmentObject(appBlocker)
                .environmentObject(profileManager)
        }
    }
}