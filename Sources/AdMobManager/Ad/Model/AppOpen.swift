//
//  AppOpen.swift
//  
//
//  Created by Trịnh Xuân Minh on 23/08/2023.
//

import Foundation

struct AppOpen: AdConfigProtocol {
  let placement: String
  let status: Bool
  let name: String
  let id: String
  let isAuto: Bool?
  let description: String?
  let timeInterval: Double?
  let params: Params?
}
