//
//  LocationDetailsView.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/7/24.
//

import SwiftUI
import MapKit


struct LocationDetailsView: View {
    @Binding var mapSelection: MKMapItem?
    @Binding var show: Bool
    var alreadyAdded = false
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 5){
//                    Text(mapSelection?.placemark.name ?? "")
//                        .font(.title2)
//                        .fontWeight(.semibold)
//                    
//                    Text(mapSelection?.placemark.title ?? "")
//                        .font(.footnote)
//                        .foregroundStyle(.gray)
//                        .lineLimit(2)
//                        .padding(.trailing)
                    
                    /// Name
                    Text(mapSelection?.placemark.name ?? "Store")
                       .font(.title2)
                       .fontWeight(.semibold)
                       .padding(.leading)
                    /// Address
                   Text(mapSelection?.placemark.title ?? "Address")
                       .font(.footnote)
                       .foregroundStyle(.gray)
                       .lineLimit(2)
                       .padding(.leading)
                    
                    /// Photo
                    ZStack{
                        ContentUnavailableView("No Preview Available", systemImage: "eye.slash")
                    }//:ZSTACK
                    .frame(height: 200)
                    .clipShape(.rect(cornerRadius: 15))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            show.toggle()
                            withAnimation(.snappy) {
                                mapSelection = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundStyle(.gray, Color(.systemGray6))
                        }//:BUTTON
                        .padding(10)
                    }
                    
                    
                    /// Add Button
                    Button(alreadyAdded ? "Added" : "Add") {
                        
                    }//:BUTTON
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.blue.gradient, in: .rect(cornerRadius: 15))
                   
                }//:VSTACK
                
                Spacer()
                
            }//:HSTACK
        }//:VSTACK
    }
}

#Preview {
    LocationDetailsView(mapSelection: .constant(nil), show: .constant(false))
}
