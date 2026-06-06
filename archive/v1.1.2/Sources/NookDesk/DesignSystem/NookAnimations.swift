import SwiftUI

enum NookAnimations {
    static let nookEase = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.25)

    static let nookFast = Animation.easeInOut(duration: 0.15)

    static let nookCardHover = Animation.easeInOut(duration: 0.3)

    static let nookSpring = Animation.spring(response: 0.3, dampingFraction: 0.6)
}
