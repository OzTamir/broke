//
//  TagSettingsView.swift
//  Broke
//

import SwiftUI

struct TagSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appBlocker: AppBlocker
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @State private var pairedCount = TagSecurity.pairedTagIDs.count
    @State private var showForgetConfirmation = false
    @State private var keyCopied = false

    private var isLocked: Bool {
        appBlocker.isBlocking || !scheduleManager.activeIDs.isEmpty
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Paired tags"), footer: Text("Only tags created on this phone with the + button work. A copy of a tag's contents on a different tag won't.")) {
                    HStack {
                        Text("Tags")
                        Spacer()
                        Text("\(pairedCount)")
                            .foregroundColor(.secondary)
                    }
                    Button("Forget All Tags", role: .destructive) {
                        showForgetConfirmation = true
                    }
                    .disabled(isLocked || pairedCount == 0)
                }

                Section(header: Text("Tap without opening Broke"), footer: Text("Keep the key private: anyone with it can make a shortcut that unblocks your phone.")) {
                    VStack(alignment: .leading, spacing: 10) {
                        SetupStep(number: 1, text: "Copy your key below.")
                        SetupStep(number: 2, text: "Open Shortcuts → Automation → + → NFC, tap Scan and hold your Broker tag to the phone.")
                        SetupStep(number: 3, text: "Choose Run Immediately, then add the \"Tap Broker Tag\" action from Broke and paste the key.")
                        SetupStep(number: 4, text: "Now tapping your tag blocks or unblocks your phone, or stops a Broke alarm, without opening the app.")
                    }
                    .padding(.vertical, 4)

                    Button(action: copyKey) {
                        Label(keyCopied ? "Key Copied" : "Copy Key", systemImage: keyCopied ? "checkmark" : "doc.on.doc")
                    }
                }
            }
            .navigationTitle("Tags & Shortcut")
            .navigationBarItems(leading: Button("Done") { dismiss() })
            .alert(isPresented: $showForgetConfirmation) {
                Alert(
                    title: Text("Forget All Tags?"),
                    message: Text("Your current tags will stop working until you create them again with the + button."),
                    primaryButton: .destructive(Text("Forget")) {
                        TagSecurity.forgetAllTags()
                        pairedCount = 0
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private func copyKey() {
        UIPasteboard.general.string = TagSecurity.phrase
        keyCopied = true
    }
}

struct SetupStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.callout)
        }
    }
}
