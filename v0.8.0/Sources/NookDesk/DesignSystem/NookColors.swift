import SwiftUI

// MARK: - Core Colors

extension Color {
    static let aiPrimary = Color(red: 0.098, green: 0.784, blue: 0.725)
    static let aiPrimaryHover = Color(red: 0.239, green: 0.831, blue: 0.776)
    static let aiPrimaryActive = Color(red: 0.067, green: 0.659, blue: 0.608)
    static let aiPrimaryBg = Color(red: 0.902, green: 0.976, blue: 0.965)

    static let aiBackground = Color(red: 0.973, green: 0.973, blue: 0.941)
    static let aiContent = Color(red: 0.969, green: 0.953, blue: 0.875)
    static let aiSecondaryBg = Color(red: 0.941, green: 0.925, blue: 0.886)

    static let aiTextBody = Color(red: 0.447, green: 0.365, blue: 0.259)
    static let aiTextHeader = Color(red: 0.475, green: 0.310, blue: 0.153)
    static let aiTextSecondary = Color(red: 0.624, green: 0.573, blue: 0.490)
    static let aiTextMuted = Color(red: 0.541, green: 0.482, blue: 0.400)
    static let aiTextDisabled = Color(red: 0.769, green: 0.722, blue: 0.620)

    static let aiBorder = Color(red: 0.624, green: 0.573, blue: 0.490)
    static let aiBorderLight = Color(red: 0.769, green: 0.722, blue: 0.620)
    static let aiBorderWarm = Color(red: 0.851, green: 0.784, blue: 0.537)

    static let aiFocusYellow = Color(red: 1.0, green: 0.800, blue: 0.0)
    static let aiSuccess = Color(red: 0.435, green: 0.729, blue: 0.173)
    static let aiWarning = Color(red: 0.961, green: 0.765, blue: 0.110)
    static let aiError = Color(red: 0.878, green: 0.353, blue: 0.353)

    static let aiShadowBtn = Color(red: 0.741, green: 0.682, blue: 0.627)
    static let aiShadowInput = Color(red: 0.831, green: 0.788, blue: 0.702)

    static let aiDivider = Color(red: 0.847, green: 0.816, blue: 0.765)
    static let aiInputBg = Color.white
    static let aiSwitchOn = Color(red: 0.525, green: 0.839, blue: 0.478)
    static let aiSwitchHandle = Color.white
    static let aiSidebarActive = Color(red: 0.718, green: 0.776, blue: 0.898)
    static let aiSidebarHover = Color(red: 0.839, green: 0.875, blue: 0.941)
    static let aiSea = Color(red: 0.686, green: 0.847, blue: 0.902)
    static let aiForest = Color(red: 0.302, green: 0.690, blue: 0.557)
    static let aiLeafFill = Color(red: 0.3, green: 0.69, blue: 0.56)
    static let aiLeafStem = Color(red: 0.45, green: 0.32, blue: 0.22)
    static let aiDangerShadow = Color(red: 0.7, green: 0.25, blue: 0.25)
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
        case .appPink:       return Color(red: 0.973, green: 0.651, blue: 0.698)
        case .purple:        return Color(red: 0.718, green: 0.490, blue: 0.933)
        case .appBlue:       return Color(red: 0.533, green: 0.616, blue: 0.941)
        case .appYellow:     return Color(red: 0.969, green: 0.804, blue: 0.404)
        case .appOrange:     return Color(red: 0.898, green: 0.573, blue: 0.400)
        case .appTeal:       return Color(red: 0.510, green: 0.835, blue: 0.733)
        case .appGreen:      return Color(red: 0.541, green: 0.776, blue: 0.541)
        case .appRed:        return Color(red: 0.988, green: 0.451, blue: 0.427)
        case .limeGreen:     return Color(red: 0.820, green: 0.855, blue: 0.286)
        case .yellowGreen:   return Color(red: 0.925, green: 0.875, blue: 0.322)
        case .brown:         return Color(red: 0.604, green: 0.514, blue: 0.353)
        case .warmPeachPink: return Color(red: 0.882, green: 0.549, blue: 0.435)
        case .nookDefault:   return Color(red: 0.969, green: 0.953, blue: 0.875)
        }
    }
}
