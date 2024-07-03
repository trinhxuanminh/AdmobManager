//
//  File.swift
//  
//
//  Created by Trịnh Xuân Minh on 03/07/2024.
//

import Foundation

struct Attributes: Codable {
  let version: String
  let state: String
  
  enum CodingKeys: String, CodingKey {
    case version = "versionString"
    case state = "appStoreState"
  }
}
