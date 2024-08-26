//
//  File.swift
//  
//
//  Created by Trịnh Xuân Minh on 26/08/2024.
//

import Foundation

extension Double {
  func rounded(decimalPlaces: Int) -> Double {
    let multiplier = pow(10.0, Double(decimalPlaces))
    return (self * multiplier).rounded() / multiplier
  }
}
