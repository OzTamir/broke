//
//  NfcReader.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//

import CoreNFC

struct TagScan {
    // First text record on the tag, if any
    let text: String?
    // Hardware serial number, which can't be rewritten on genuine NTAG chips
    let tagID: String
}

// Uses a tag reader session rather than an NDEF session so we can see the tag's serial number
class NFCReader: NSObject, ObservableObject, NFCTagReaderSessionDelegate {
    private var session: NFCTagReaderSession?
    private var onScanComplete: ((TagScan) -> Void)?
    private var onWriteComplete: ((String?) -> Void)?
    private var textToWrite: String?

    static var isAvailable: Bool {
        NFCTagReaderSession.readingAvailable
    }

    func scan(completion: @escaping (TagScan) -> Void) {
        onScanComplete = completion
        textToWrite = nil
        startSession(message: "Hold your iPhone near your Broker tag.")
    }

    // Completes with the written tag's serial number, or nil on failure
    func write(_ text: String, completion: @escaping (String?) -> Void) {
        onWriteComplete = completion
        textToWrite = text
        startSession(message: "Hold your iPhone near an NFC tag to write.")
    }

    private func startSession(message: String) {
        guard Self.isAvailable else {
            NSLog("NFC is not available on this device")
            return
        }

        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil)
        session?.alertMessage = message
        session?.begin()
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = "More than 1 tag detected. Please try again with only one tag."
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                session.restartPolling()
            }
            return
        }
        guard case let .miFare(miFareTag) = tag else {
            session.invalidate(errorMessage: "Unsupported tag. Use an NTAG213, 215 or 216.")
            return
        }

        let tagID = miFareTag.identifier.map { String(format: "%02x", $0) }.joined()
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
                return
            }

            if let text = self.textToWrite {
                self.write(text, to: miFareTag, tagID: tagID, session: session)
            } else {
                self.read(miFareTag, tagID: tagID, session: session)
            }
        }
    }

    private func read(_ tag: NFCMiFareTag, tagID: String, session: NFCTagReaderSession) {
        tag.queryNDEFStatus { status, _, error in
            if let error = error {
                session.invalidate(errorMessage: "Failed to query tag: \(error.localizedDescription)")
                return
            }
            guard status != .notSupported else {
                session.invalidate(errorMessage: "Tag is not NDEF compliant")
                return
            }

            tag.readNDEF { message, _ in
                // A blank tag has no message; report it so the app can say it's not a Broker tag
                let text = message.flatMap(Self.firstText)
                session.alertMessage = "Tag read successfully!"
                session.invalidate()
                DispatchQueue.main.async {
                    self.onScanComplete?(TagScan(text: text, tagID: tagID))
                }
            }
        }
    }

    private func write(_ text: String, to tag: NFCMiFareTag, tagID: String, session: NFCTagReaderSession) {
        tag.queryNDEFStatus { status, _, error in
            guard error == nil else {
                session.invalidate(errorMessage: "Failed to query tag")
                return
            }

            switch status {
            case .notSupported:
                session.invalidate(errorMessage: "Tag is not NDEF compliant")
            case .readOnly:
                session.invalidate(errorMessage: "Tag is read-only")
            case .readWrite:
                let payload = NFCNDEFPayload.wellKnownTypeTextPayload(string: text, locale: Locale(identifier: "en"))!
                tag.writeNDEF(NFCNDEFMessage(records: [payload])) { error in
                    if let error = error {
                        session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                    } else {
                        session.alertMessage = "Write successful!"
                        session.invalidate()
                    }

                    DispatchQueue.main.async {
                        self.onWriteComplete?(error == nil ? tagID : nil)
                    }
                }
            @unknown default:
                session.invalidate(errorMessage: "Unknown tag status")
            }
        }
    }

    // Tags can carry several records; only the first text record matters
    private static func firstText(in message: NFCNDEFMessage) -> String? {
        for record in message.records where record.typeNameFormat == .nfcWellKnown {
            if let text = record.wellKnownTypeTextPayload().0 {
                return text
            }
        }
        return nil
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError,
           readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead,
           readerError.code != .readerSessionInvalidationErrorUserCanceled {
            NSLog("Session invalidated with error: \(error.localizedDescription)")
        }
        self.session = nil
    }
}
