import SwiftUI

struct MainView: View {
    @StateObject private var appBlocker = AppBlocker()
    @StateObject private var nfcReader = NFCReader()
    private let tagPhrase = "BROKE-IS-GREAT"
    
    var body: some View {
        TabView {
            BrokerView(appBlocker: appBlocker, nfcReader: nfcReader, tagPhrase: tagPhrase)
                .tabItem {
                    Label("Broker", systemImage: "lock.shield")
                }
            
            SettingsView(appBlocker: appBlocker)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
