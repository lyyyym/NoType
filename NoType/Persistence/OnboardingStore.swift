import Foundation

/// Persists and loads `OnboardingState` from the Application Support directory.
final class OnboardingStore {

    private let store = JSONFileStore<OnboardingState>(filename: "onboarding.json")

    /// Loads the current onboarding state. Returns a fresh state if the file is missing.
    func load() -> OnboardingState {
        do {
            return (try store.load()) ?? OnboardingState()
        } catch {
            print("[OnboardingStore] failed to load: \(error.localizedDescription)")
            return OnboardingState()
        }
    }

    /// Saves the onboarding state to disk.
    func save(_ state: OnboardingState) {
        do {
            try store.save(state)
        } catch {
            print("[OnboardingStore] failed to save: \(error.localizedDescription)")
        }
    }

    /// Marks onboarding as completed and persists it.
    func complete() {
        var state = load()
        state.hasCompletedOnboarding = true
        save(state)
    }
}
