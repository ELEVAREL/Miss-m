import LocalAuthentication

// MARK: - Touch ID Service (Phase 7)
// LAContext — Touch ID lock for app access

@Observable
class TouchIDService {
    static let shared = TouchIDService()

    var isLocked = false
    var isEnabled = false

    private let context = LAContext()

    // MARK: - Check Availability

    var isBiometricAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var biometricType: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        @unknown default: return "Biometric"
        }
    }

    // MARK: - Authenticate

    func authenticate(reason: String = "Unlock Miss M") async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fall back to device passcode
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                return false
            }
            return await evaluatePolicy(.deviceOwnerAuthentication, context: context, reason: reason)
        }

        return await evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, context: context, reason: reason)
    }

    private func evaluatePolicy(_ policy: LAPolicy, context: LAContext, reason: String) async -> Bool {
        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            if success {
                isLocked = false
            }
            return success
        } catch {
            return false
        }
    }

    // MARK: - Lock / Unlock

    func lock() {
        guard isEnabled else { return }
        isLocked = true
    }

    func unlock() async -> Bool {
        guard isLocked else { return true }
        return await authenticate()
    }
}
