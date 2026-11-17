import SwiftUI

/// the Mac's accent colour, for the settings window only. the app ships a
/// gold accent of its own, and with the Mac on Multicolor (the default)
/// macOS would hand settings that gold; this reads the choice the person
/// made in System Settings › Appearance instead, and is blue when they
/// made none.
enum SystemAccent {
    /// the global `AppleAccentColor` value: absent means Multicolor.
    static func color(stored: Int?) -> Color {
        switch stored {
        case -1: .gray
        case 0: .red
        case 1: .orange
        case 2: .yellow
        case 3: .green
        case 4: .blue
        case 5: .purple
        case 6: .pink
        default: .blue
        }
    }

    static var color: Color {
        color(stored: UserDefaults.standard.object(forKey: "AppleAccentColor") as? Int)
    }
}
