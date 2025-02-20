//
//  Attendancemanager.swift
//  Broke
//
//  Created by Theo Steiger on 2/13/25.
//

import SwiftUI

// A simple model for each attendance record.
struct AttendanceRecord: Identifiable, Codable {
    let id: UUID
    let profileName: String
    let date: Date

    init(profileName: String) {
        self.id = UUID()
        self.profileName = profileName
        self.date = Date()
    }
}

// The manager that holds attendance records.
class AttendanceManager: ObservableObject {
    @Published var records: [AttendanceRecord] = []
    
    // Log attendance for a given profile.
    func logAttendance(for profile: Profile) {
        let record = AttendanceRecord(profileName: profile.name)
        records.append(record)
        // Optionally, save to persistent storage (UserDefaults, file, or Core Data)
        print("Logged attendance for \(profile.name) at \(record.date)")
    }
}
