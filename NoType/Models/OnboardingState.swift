import Foundation

/// Tracks the user's progress through the first-launch onboarding wizard.
struct OnboardingState: Codable {
    var hasCompletedOnboarding: Bool = false
    var microphonePermissionRequested: Bool = false
    var accessibilityPermissionRequested: Bool = false
    var basicConfigSaved: Bool = false
}
