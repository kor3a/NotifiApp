//
//  ProfileView.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/5/24.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        if viewModel.isLoading {
            VStack {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                Text("Loading profile...")
                    .foregroundStyle(.gray)
            }
        } else if !viewModel.errorMessage.isEmpty {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(.red)
                    .padding()
                Text(viewModel.errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Retry") {
                    viewModel.fetchUser()
                }
                .padding()
                Button("Sign Out") {
                    viewModel.signOut()
                }
                .foregroundStyle(.red)
            }
            .padding()
        } else if let user = viewModel.user {
            profileLoginView(user: user)
        } else {
            Text("No user data available")
                .foregroundStyle(.gray)
        }
    }

    @ViewBuilder
    func profileLoginView(user: User) -> some View {
        VStack {
            Image(systemName: "person.circle")
                .resizable()
                .frame(width: 80, height: 80)
                .padding(.top, 50)
                .padding(.bottom, 20)

            VStack(spacing: 10) {
                Text(user.name)
                    .bold()
                    .font(.title)

                Text("@\(user.userId)")
                    .font(.title3)
                    .foregroundStyle(.gray)

                Text(user.email)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Text("Joined: \(formatDate(user.joined))")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(.top, 5)
            }
            .padding()

            Spacer()

            Button {
                viewModel.signOut()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 25.0)
                        .fill(.red.opacity(0.1))
                        .frame(width: 300, height: 50)

                    Text("Sign Out")
                        .font(.title3)
                        .bold()
                        .foregroundStyle(.red)
                }
            }
            .padding(.bottom, 30)
        }
    }

    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    ProfileView()
}
