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
            VStack {
                    Image(systemName: "person.circle")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .padding(.horizontal, 10)
                    
                    VStack {
                        Text("James Je")
                            .bold()
                            .font(.title)
                        
                        Text("example@gmail.com")
                            .bold()
                            .font(.title2)
                        
                        Text("Date of Joined: 05/15/2025")
                            .foregroundStyle(.gray)
                    }//:VSTACK
                }//:VSTACK
                .padding(.top, 50)
                
                Spacer()
                
                Button {
                    viewModel.signOut()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 25.0)
                            .frame(width: 300, height: 50)
                        
                        Text("Sign Out")
                            .font(.title3)
                            .foregroundStyle(.red)
                    }//:ZSTACK
                }//:BUTTON
        }//:BODY
            
        
//        if let user = viewModel.user {
//            profileLoginView(user: user)
//        } else {
//            Text("loading user...")
//        }
        
    
    @ViewBuilder
    func profileLoginView(user: User) -> some View {
        VStack {
            HStack {
                Image(systemName: "person.circle")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .padding(.horizontal, 10)
                
                VStack {
                    Text(user.name)
                        .bold()
                        .font(.title)
                    
                    Text(user.email)
                        .bold()
                        .font(.title2)
                    
                    Text("Date of Joined: \(Date(timeIntervalSince1970: user.joined))")
                        .foregroundStyle(.gray)
                }//:VSTACK
            }//:HSTACK
            .padding(.top, 50)
            
            Spacer()
            
            Button {
                viewModel.signOut()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 25.0)
                        .frame(width: 300, height: 50)
                    
                    Text("Sign Out")
                        .font(.title3)
                        .foregroundStyle(.red)
                }//:ZSTACK
            }//:BUTTON
        }
        
    }
}

#Preview {
    ProfileView()
}
