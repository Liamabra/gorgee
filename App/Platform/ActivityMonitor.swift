import CoreGraphics

/// L'utilisateur se sert-il du Mac ? Une saisie dans les 3 dernières minutes, session déverrouillée.
enum ActivityMonitor {
    static let idleThreshold: Double = 180

    static func isUserActive() -> Bool {
        secondsSinceLastInput() < idleThreshold && !isSessionLocked()
    }

    static func secondsSinceLastInput() -> Double {
        // kCGAnyInputEventType vaut ~0.
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    static func isSessionLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (session["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }
}
