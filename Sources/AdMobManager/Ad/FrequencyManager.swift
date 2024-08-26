//
//  File.swift
//  
//
//  Created by Trịnh Xuân Minh on 15/11/2023.
//

import Foundation

class FrequencyManager {
  static let shared = FrequencyManager()
  
  enum Keys {
    static let cache = "FrequencyCache"
  }
  
  private var countClicks: [String: Int] = [:]
  
  init() {
    fetch()
  }
}

extension FrequencyManager {
  func getCount(placement: String) -> Int {
    return countClicks[placement] ?? 0
  }
  
  func increaseCount(placement: String) {
    let count = getCount(placement: placement)
    countClicks[placement] = count + 1
    save()
  }
}

extension FrequencyManager {
  private func fetch() {
    guard let countClicks = UserDefaults.standard.dictionary(forKey: Keys.cache) as? [String: Int] else {
      return
    }
    self.countClicks = countClicks
  }
  
  private func save() {
//    UserDefaults.standard.set(countClicks, forKey: Keys.cache)
  }
}
