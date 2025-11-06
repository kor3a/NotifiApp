//
//  Reminder.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/14/24.
//

import Foundation

struct Reminder: Codable, Identifiable {
    let id = UUID()
    let userStoreId : String
    let title: String
    var isDone: Bool
}
