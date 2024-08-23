import SwiftUI

struct MainView: View {
    @StateObject private var appBlocker = AppBlocker()
    @StateObject private var nfcReader = NFCReader()
    @StateObject private var profileManager = ProfileManager()
    private let tagPhrase = "BROKE-IS-GREAT"
    
    var body: some View {
        TabView {
            BrokerView(appBlocker: appBlocker, nfcReader: nfcReader, profileManager: profileManager, tagPhrase: tagPhrase)
                .tabItem {
                    Label("Broker", systemImage: "lock.shield")
                }
            
            SettingsView(appBlocker: appBlocker, profileManager: profileManager)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}