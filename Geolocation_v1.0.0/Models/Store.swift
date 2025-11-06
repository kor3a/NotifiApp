//
//  Store.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/14/24.
//

import Foundation

struct Store: Codable, Identifiable {
    let id = UUID()
    let name: String
    let address: String
}
