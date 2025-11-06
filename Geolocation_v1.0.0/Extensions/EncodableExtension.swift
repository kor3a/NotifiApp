//
//  EncodableExtension.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/5/24.
//

import Foundation

extension Encodable {
    func asDict() -> [String : Any] {
        guard let data = try? JSONEncoder().encode(self) else {
            return [:] //return empty array
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String : Any]
            return json ?? [:]
        } catch {
            return [:]
        }
    }
}
