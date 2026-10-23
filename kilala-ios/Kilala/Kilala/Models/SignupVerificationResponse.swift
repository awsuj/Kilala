//
//  Untitled.swift
//  Kilala
//
//  Created by Eunice Santos on 10/23/26.
//

import Foundation

struct SignupVerificationResponse: Codable {
    let message: String
    let profileId: UUID
    let firstName: String
    let middleName: String?
    let lastName: String
}
