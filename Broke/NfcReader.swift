//
//  NfcReader.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//

import CoreNFC

class NFCReader: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    @Published var message = "Waiting for NFC tag..."
    var session: NFCNDEFReaderSession?
    
    func scan() {
        NSLog("Attempting to start NFC scan")
        guard NFCNDEFReaderSession.readingAvailable else {
            NSLog("NFC reading is not available on this device")
            return
        }
        
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = "Hold your iPhone near an NFC tag."
        session?.begin()
        NSLog("NFC session begun")
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        NSLog("NFC tag detected")
        guard let ndefMessage = messages.first,
              let record = ndefMessage.records.first,
              let payload = String(data: record.payload, encoding: .utf8) else {
            NSLog("Failed to read NFC tag content")
            return
        }
        
        DispatchQueue.main.async {
            self.message = payload
            NSLog("NFC Tag Content: \(payload)")
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        NSLog("NFC session invalidated with error: \(error.localizedDescription)")
    }
}
