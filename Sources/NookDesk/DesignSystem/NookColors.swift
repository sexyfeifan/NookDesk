import SwiftUI
import AppKit

// MARK: - Adaptive Color Helper

extension Color {
    /// Creates a color that adapts between light and dark mode via NSColor dynamic provider.
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(dark)
                : NSColor(light)
        })
    }
}

// MARK: - Core Colors

extension Color {
    static let aiPrimary = Color(
        light: Color(red: 0.098, green: 0.784, blue: 0.725),
        dark:  Color(red: 0.157, green: 0.843, blue: 0.784)
    )
    static let aiPrimaryHover = Color(
        light: Color(red: 0.239, green: 0.831, blue: 0.776),
        dark:  Color(red: 0.278, green: 0.863, blue: 0.812)
    )
    static let aiPrimaryActive = Color(
        light: Color(red: 0.067, green: 0.659, blue: 0.608),
        dark:  Color(red: 0.118, green: 0.725, blue: 0.675)
    )
    static let aiPrimaryBg = Color(
        light: Color(red: 0.902, green: 0.976, blue: 0.965),
        dark:  Color(red: 0.078, green: 0.157, blue: 0.149)
    )

    static let aiBackground = Color(
        light: Color(red: 0.973, green: 0.973, blue: 0.941),
        dark:  Color(red: 0.110, green: 0.110, blue: 0.118)
    )
    static let aiContent = Color(
        light: Color(red: 0.969, green: 0.953, blue: 0.875),
        dark:  Color(red: 0.149, green: 0.145, blue: 0.141)
    )
    static let aiSecondaryBg = Color(
        light: Color(red: 0.941, green: 0.925, blue: 0.886),
        dark:  Color(red: 0.169, green: 0.165, blue: 0.157)
    )

    static let aiTextBody = Color(
        light: Color(red: 0.447, green: 0.365, blue: 0.259),
        dark:  Color(red: 0.851, green: 0.824, blue: 0.769)
    )
    static let aiTextHeader = Color(
        light: Color(red: 0.475, green: 0.310, blue: 0.153),
        dark:  Color(red: 0.902, green: 0.863, blue: 0.784)
    )
    static let aiTextSecondary = Color(
        light: Color(red: 0.624, green: 0.573, blue: 0.490),
        dark:  Color(red: 0.667, green: 0.627, blue: 0.569)
    )
    static let aiTextMuted = Color(
        light: Color(red: 0.541, green: 0.482, blue: 0.400),
        dark:  Color(red: 0.569, green: 0.529, blue: 0.471)
    )
    static let aiTextDisabled = Color(
        light: Color(red: 0.769, green: 0.722, blue: 0.620),
        dark:  Color(red: 0.392, green: 0.369, blue: 0.333)
    )

    static let aiBorder = Color(
        light: Color(red: 0.624, green: 0.573, blue: 0.490),
        dark:  Color(red: 0.333, green: 0.314, blue: 0.290)
    )
    static let aiBorderLight = Color(
        light: Color(red: 0.769, green: 0.722, blue: 0.620),
        dark:  Color(red: 0.275, green: 0.259, blue: 0.243)
    )
    static let aiBorderWarm = Color(
        light: Color(red: 0.851, green: 0.784, blue: 0.537),
        dark:  Color(red: 0.431, green: 0.392, blue: 0.267)
    )

    static let aiFocusYellow = Color(
        light: Color(red: 1.0, green: 0.800, blue: 0.0),
        dark:  Color(red: 1.0, green: 0.843, blue: 0.196)
    )
    static let aiSuccess = Color(
        light: Color(red: 0.435, green: 0.729, blue: 0.173),
        dark:  Color(red: 0.510, green: 0.784, blue: 0.275)
    )
    static let aiWarning = Color(
        light: Color(red: 0.961, green: 0.765, blue: 0.110),
        dark:  Color(red: 0.980, green: 0.804, blue: 0.216)
    )
    static let aiError = Color(
        light: Color(red: 0.878, green: 0.353, blue: 0.353),
        dark:  Color(red: 0.941, green: 0.431, blue: 0.431)
    )

    static let aiShadowBtn = Color(
        light: Color(red: 0.741, green: 0.682, blue: 0.627),
        dark:  Color(red: 0.059, green: 0.055, blue: 0.051)
    )
    static let aiShadowInput = Color(
        light: Color(red: 0.831, green: 0.788, blue: 0.702),
        dark:  Color(red: 0.039, green: 0.039, blue: 0.035)
    )

    static let aiDivider = Color(
        light: Color(red: 0.847, green: 0.816, blue: 0.765),
        dark:  Color(red: 0.235, green: 0.224, blue: 0.212)
    )
    static let aiInputBg = Color(
        light: Color.white,
        dark:  Color(red: 0.176, green: 0.173, blue: 0.165)
    )
    static let aiSwitchOn = Color(
        light: Color(red: 0.525, green: 0.839, blue: 0.478),
        dark:  Color(red: 0.569, green: 0.863, blue: 0.529)
    )
    static let aiSwitchHandle = Color(
        light: Color.white,
        dark:  Color(red: 0.882, green: 0.863, blue: 0.824)
    )
    static let aiSidebarActive = Color(
        light: Color(red: 0.718, green: 0.776, blue: 0.898),
        dark:  Color(red: 0.275, green: 0.333, blue: 0.471)
    )
    static let aiSidebarHover = Color(
        light: Color(red: 0.839, green: 0.875, blue: 0.941),
        dark:  Color(red: 0.196, green: 0.224, blue: 0.290)
    )
    static let aiSea = Color(
        light: Color(red: 0.686, green: 0.847, blue: 0.902),
        dark:  Color(red: 0.275, green: 0.431, blue: 0.490)
    )
    static let aiForest = Color(
        light: Color(red: 0.302, green: 0.690, blue: 0.557),
        dark:  Color(red: 0.196, green: 0.431, blue: 0.353)
    )
    static let aiLeafFill = Color(
        light: Color(red: 0.3, green: 0.69, blue: 0.56),
        dark:  Color(red: 0.224, green: 0.510, blue: 0.408)
    )
    static let aiLeafStem = Color(
        light: Color(red: 0.45, green: 0.32, blue: 0.22),
        dark:  Color(red: 0.549, green: 0.431, blue: 0.314)
    )
    static let aiDangerShadow = Color(
        light: Color(red: 0.7, green: 0.25, blue: 0.25),
        dark:  Color(red: 0.471, green: 0.157, blue: 0.157)
    )
}

// MARK: - NookPhone Card Colors

enum NookColor: String, CaseIterable, Identifiable {
    case appPink
    case purple
    case appBlue
    case appYellow
    case appOrange
    case appTeal
    case appGreen
    case appRed
    case limeGreen
    case yellowGreen
    case brown
    case warmPeachPink
    case nookDefault

    var id: String { rawValue }

    var blogValue: String {
        if self == .nookDefault { return "app-blue" }
        var result = ""
        for char in rawValue {
            if char.isUppercase {
                if !result.isEmpty { result += "-" }
                result += char.lowercased()
            } else {
                result.append(char)
            }
        }
        return result
    }

    static func fromBlogValue(_ bv: String) -> NookColor {
        allCases.first { $0.blogValue == bv } ?? .appBlue
    }

    var color: Color {
        switch self {
        case .appPink:       return Color(light: Color(red: 0.973, green: 0.651, blue: 0.698),
                                          dark:  Color(red: 0.804, green: 0.392, blue: 0.451))
        case .purple:        return Color(light: Color(red: 0.718, green: 0.490, blue: 0.933),
                                          dark:  Color(red: 0.588, green: 0.353, blue: 0.843))
        case .appBlue:       return Color(light: Color(red: 0.533, green: 0.616, blue: 0.941),
                                          dark:  Color(red: 0.392, green: 0.471, blue: 0.863))
        case .appYellow:     return Color(light: Color(red: 0.969, green: 0.804, blue: 0.404),
                                          dark:  Color(red: 0.824, green: 0.647, blue: 0.235))
        case .appOrange:     return Color(light: Color(red: 0.898, green: 0.573, blue: 0.400),
                                          dark:  Color(red: 0.745, green: 0.412, blue: 0.235))
        case .appTeal:       return Color(light: Color(red: 0.510, green: 0.835, blue: 0.733),
                                          dark:  Color(red: 0.353, green: 0.667, blue: 0.569))
        case .appGreen:      return Color(light: Color(red: 0.541, green: 0.776, blue: 0.541),
                                          dark:  Color(red: 0.373, green: 0.608, blue: 0.373))
        case .appRed:        return Color(light: Color(red: 0.988, green: 0.451, blue: 0.427),
                                          dark:  Color(red: 0.843, green: 0.294, blue: 0.275))
        case .limeGreen:     return Color(light: Color(red: 0.820, green: 0.855, blue: 0.286),
                                          dark:  Color(red: 0.647, green: 0.686, blue: 0.157))
        case .yellowGreen:   return Color(light: Color(red: 0.925, green: 0.875, blue: 0.322),
                                          dark:  Color(red: 0.765, green: 0.706, blue: 0.176))
        case .brown:         return Color(light: Color(red: 0.604, green: 0.514, blue: 0.353),
                                          dark:  Color(red: 0.471, green: 0.373, blue: 0.216))
        case .warmPeachPink: return Color(light: Color(red: 0.882, green: 0.549, blue: 0.435),
                                          dark:  Color(red: 0.725, green: 0.392, blue: 0.275))
        case .nookDefault:   return Color(light: Color(red: 0.969, green: 0.953, blue: 0.875),
                                          dark:  Color(red: 0.149, green: 0.145, blue: 0.141))
        }
    }
}
