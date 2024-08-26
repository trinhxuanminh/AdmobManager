//
//  File.swift
//  
//
//  Created by Trịnh Xuân Minh on 26/08/2024.
//

import UIKit

extension UIViewController {
  func getScreen() -> String {
    return String(describing: type(of: self))
  }
}
