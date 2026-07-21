import Foundation
import Testing
@testable import NoType

@Suite("OnboardingState")
struct OnboardingStateTests {

    @Test func freshStateIsNotCompleted() {
        let state = OnboardingState()
        #expect(state.hasCompletedOnboarding == false)
        #expect(state.microphonePermissionRequested == false)
        #expect(state.accessibilityPermissionRequested == false)
        #expect(state.basicConfigSaved == false)
    }

    @Test func storeSavesAndLoadsState() throws {
        let store = OnboardingStore()
        var state = OnboardingState()
        state.microphonePermissionRequested = true
        state.accessibilityPermissionRequested = true
        state.basicConfigSaved = true
        state.hasCompletedOnboarding = true
        store.save(state)

        let loaded = store.load()
        #expect(loaded.hasCompletedOnboarding == true)
        #expect(loaded.microphonePermissionRequested == true)
        #expect(loaded.accessibilityPermissionRequested == true)
        #expect(loaded.basicConfigSaved == true)

        // Clean up.
        try? JSONFileStore<OnboardingState>(filename: "onboarding.json").delete()
    }
}
