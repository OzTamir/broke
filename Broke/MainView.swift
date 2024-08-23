import SwiftUI

struct MainView: View {
    @StateObject private var appBlocker = AppBlocker()
    @StateObject private var nfcReader = NFCReader()
    
    var body: some View {
        TabView {
            BrokerView(appBlocker: appBlocker)
                .tabItem {
                    Label("Broker", systemImage: "lock.shield")
                }
            
            SettingsView(appBlocker: appBlocker, nfcReader: nfcReader)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
