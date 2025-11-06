//
//  StoreReminderView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/14/24.
//

import SwiftUI

struct ReminderItemView: View {
    let item: Reminder
    @StateObject private var viewModel = ReminderItemViewModel()
    
    var body: some View {
        HStack {
            
            Image(systemName: item.isDone ? "checkmark.square" : "square")
            
            Text(item.title)
                .font(.headline)
                .bold()
            
            Spacer()
            
            
        }//:HSTACK
        
    }
}

