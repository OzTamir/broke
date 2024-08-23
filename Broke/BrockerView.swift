//
//  BrockerView.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//
import SwiftUI

struct BrokerView: View {
    @ObservedObject var appBlocker: AppBlocker
    
    var body: some View {
        ZStack {
            Circle()
                .fill(appBlocker.isBlocking ? Color.red : Color.green)
                .frame(width: 200, height: 200)
                .overlay(
                    Text(appBlocker.isBlocking ? "Blocking" : "Not Blocking")
                        .foregroundColor(.white)
                        .font(.headline)
                )
                .onTapGesture {
                    appBlocker.toggleBlocking()
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}
