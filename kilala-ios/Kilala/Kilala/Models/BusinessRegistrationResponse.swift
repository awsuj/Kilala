//
//  BusinessRegistrationResponse.swift
//  Kilala
//
//  Created by Joshua Calibo on 10/23/26.
//

import Foundation

struct BusinessRegistrationResponse: Codable {
    let message: String
    let token: String
    let user: User
    let businessProfile: BusinessProfile
}
