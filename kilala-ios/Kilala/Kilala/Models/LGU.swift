//
//  LGU.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/23/26.
//

import Foundation

struct LGU: Codable, Identifiable, Hashable {
    let id: UUID
    let lguCode: String
    let municipalityName: String
    let province: String?
    let region: String
}
