//
//  AttendanceRecordsView.swift
//  Broke
//
//  Created by Theo Steiger on 2/13/25.
//

import SwiftUI

struct AttendanceRecordsView: View {
    @EnvironmentObject var attendanceManager: AttendanceManager

    var body: some View {
        NavigationView {
            List(attendanceManager.records) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile: \(record.profileName)")
                        .font(.headline)
                    Text("Time: \(record.date, formatter: DateFormatter.attendanceFormatter)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Attendance Records")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Optionally, you could add a "Clear" button here
                    Button("Clear") {
                        attendanceManager.records.removeAll()
                    }
                }
            }
        }
    }
}

// A DateFormatter extension to format attendance timestamps.
extension DateFormatter {
    static var attendanceFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

struct AttendanceRecordsView_Previews: PreviewProvider {
    static var previews: some View {
        AttendanceRecordsView()
            .environmentObject(AttendanceManager())
    }
}

