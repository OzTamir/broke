//
//  ProfilePicker.swift
//  Broke
//
//  Created by Oz Tamir on 23/08/2024.
//

import SwiftUI

struct ProfilesPicker: View {
    @ObservedObject var profileManager: ProfileManager
    @Binding var showAddProfileAlert: Bool
    
    var body: some View {
        VStack {
            HStack {
                Text("Profiles")
                    .font(.headline)
                Spacer()
                Button(action: {
                    showAddProfileAlert = true
                }) {
                    Image(systemName: "plus")
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                    ForEach(profileManager.profiles) { profile in
                        ProfileCell(profile: profile, isSelected: profile.id == profileManager.currentProfile.id)
                            .onTapGesture {
                                profileManager.setCurrentProfile(id: profile.id)
                            }
                    }
                }
                .padding()
            }
        }
        .background(Color("ProfileSectionBackground"))
    }
}

struct ProfileCell: View {
    let profile: Profile
    let isSelected: Bool

    var body: some View {
        VStack {
            Image(systemName: profile.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
            Text(profile.name)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(width: 100, height: 100)
        .background(isSelected ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.2))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}
