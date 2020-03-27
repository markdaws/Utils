//
//  File.swift
//  
//
//  Created by Mark Dawson on 3/27/20.
//

import Foundation
import UIKit

extension UIColor {

  /// Returns a random color
  static func random() -> UIColor {
    return UIColor(
      red: CGFloat.random(in: 0...1),
      green: CGFloat.random(in: 0...1),
      blue: CGFloat.random(in: 0...1),
      alpha: 1.0
    )
  }

  public static func fromHex(_ hex: String) -> UIColor {
    var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

    if cString.hasPrefix("#") {
      cString.remove(at: cString.startIndex)
    }

    if (cString.count) != 6 {
      return UIColor(red: 128/255.0, green: 128/255.0, blue: 128/255.0, alpha: 1)
    }

    var rgbValue: UInt32 = 0
    Scanner(string: cString).scanHexInt32(&rgbValue)
    return UIColor(
      red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
      green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
      blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
      alpha: 1
    )
  }

}
