//
//  File.swift
//  
//
//  Created by Trịnh Xuân Minh on 26/08/2024.
//

import Foundation
import AVFoundation

class TimeManager {
  static let shared = TimeManager()
  
  private var startTimes: [String: CFTimeInterval] = [:]
  
  func start(event: Event) {
    let start = CACurrentMediaTime()
    startTimes[event.key] = start
  }
  
  func end(event: Event) -> Double {
    let end = CACurrentMediaTime()
    guard let start = startTimes.removeValue(forKey: event.key) else {
      return 0
    }
    return Double(end - start).rounded(decimalPlaces: 1)
  }
  
  enum Event {
    case adLoad(AdMobManager.AdType, String)
    
    var key: String {
      switch self {
      case .adLoad(let adType, let id):
        return "\(self)_\(adType)_\(id)"
      }
    }
  }
}
