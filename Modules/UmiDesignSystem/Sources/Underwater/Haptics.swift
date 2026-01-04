import SwiftUI
import CoreHaptics

public enum Haptics {
    public static func tap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.6)
    }
    public static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    public static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    public static func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }
}