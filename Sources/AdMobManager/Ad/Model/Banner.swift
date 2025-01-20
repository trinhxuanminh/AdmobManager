//
//  Banner.swift
//  
//
//  Created by Trịnh Xuân Minh on 23/08/2023.
//

import Foundation

struct Banner: AdConfigProtocol {
  let placement: String
  let status: Bool
  let name: String
  let id: String
  let isAuto: Bool?
  let description: String?
  let anchored: String?
  let params: Params?
}
