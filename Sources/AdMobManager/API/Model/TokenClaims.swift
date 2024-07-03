//
//  File.swift
//  
//
//  Created by Trịnh Xuân Minh on 03/07/2024.
//

import Foundation
import SwiftJWT

struct TokenClaims: Claims {
  let iss: String
  let exp: Date
  let aud: String
}
