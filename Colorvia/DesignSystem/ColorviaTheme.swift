import SwiftUI
import UIKit

enum ColorviaTheme {
  static let background = adaptive(
    light: UIColor(red: 0.965, green: 0.965, blue: 0.945, alpha: 1),
    dark: UIColor(red: 0.055, green: 0.075, blue: 0.08, alpha: 1)
  )
  static let sea = adaptive(
    light: UIColor(red: 0.89, green: 0.93, blue: 0.93, alpha: 1),
    dark: UIColor(red: 0.10, green: 0.16, blue: 0.17, alpha: 1)
  )
  static let land = adaptive(
    light: UIColor(red: 0.98, green: 0.975, blue: 0.955, alpha: 1),
    dark: UIColor(red: 0.20, green: 0.23, blue: 0.23, alpha: 1)
  )
  static let border = adaptive(
    light: UIColor(red: 0.70, green: 0.75, blue: 0.75, alpha: 1),
    dark: UIColor(red: 0.34, green: 0.40, blue: 0.40, alpha: 1)
  )
  static let accent = adaptive(
    light: UIColor(red: 0.29, green: 0.57, blue: 0.57, alpha: 1),
    dark: UIColor(red: 0.34, green: 0.70, blue: 0.68, alpha: 1)
  )
  static let accentDeep = adaptive(
    light: UIColor(red: 0.10, green: 0.33, blue: 0.34, alpha: 1),
    dark: UIColor(red: 0.26, green: 0.64, blue: 0.62, alpha: 1)
  )
  static let ink = adaptive(
    light: UIColor(red: 0.10, green: 0.24, blue: 0.25, alpha: 1),
    dark: UIColor(red: 0.91, green: 0.95, blue: 0.94, alpha: 1)
  )
  static let secondaryInk = adaptive(
    light: UIColor(red: 0.38, green: 0.42, blue: 0.42, alpha: 1),
    dark: UIColor(red: 0.65, green: 0.71, blue: 0.70, alpha: 1)
  )
  static let card = adaptive(
    light: UIColor(white: 1, alpha: 0.92),
    dark: UIColor(red: 0.105, green: 0.13, blue: 0.135, alpha: 0.96)
  )

  static func logoFont(size: CGFloat) -> Font {
    .system(size: size, weight: .regular, design: .serif)
  }

  private static func adaptive(light: UIColor, dark: UIColor) -> Color {
    Color(
      uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
      })
  }
}
