//
//  VerificationResponse.swift
//  
//
//  Created by Kirill Kunst on 17.07.2023.
//

import Foundation

struct VerificationResponse: Codable {
    let code: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case code
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}
