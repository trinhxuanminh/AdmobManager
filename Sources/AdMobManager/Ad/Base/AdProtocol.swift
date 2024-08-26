//
//  AdProtocol.swift
//  
//
//  Created by Trịnh Xuân Minh on 23/06/2022.
//

import UIKit

protocol AdProtocol {
  func config(didFail: Handler?, didSuccess: Handler?)
  func config(id: String, name: String)
  func isPresent() -> Bool
  func isExist() -> Bool
  func show(placement: String,
            rootViewController: UIViewController,
            didFail: Handler?,
            willPresent: Handler?,
            didEarnReward: Handler?,
            didHide: Handler?)
}

extension AdProtocol {
  func config(timeout: Double) {}
}
