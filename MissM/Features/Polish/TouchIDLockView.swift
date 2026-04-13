import SwiftUI
import LocalAuthentication

// MARK: - Touch ID Lock Manager

@Observable
class TouchIDManager {
    var isLocked = false
    var lockEnabled = false
    var errorMessage = ""

    func checkBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedReason = "Unlock Miss M"
        context.localizedCancelTitle = "Cancel"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to access Miss M"
            )
            if success {
                isLocked = false
                errorMessage = ""
            }
            return success
        } catch {
            errorMessage = "Authentication failed"
            return false
        }
    }

    func lock() {
        isLocked = true
    }
}

// MARK: - Touch ID Lock Screen

struct TouchIDLockView: View {
    @Binding var isLocked: Bool
    let touchID: TouchIDManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("\u{265B}")
                .font(.system(size: 48))

            Text("Miss M is Locked")
                .font(Theme.Fonts.display(22))
                .foregroundColor(Theme.Colors.rosePrimary)

            Text("Use Touch ID to unlock")
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSoft)

            Button(action: {
                Task {
                    let success = await touchID.authenticate()
                    if success { isLocked = false }
                }
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "touchid")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Text("Touch ID")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.textMedium)
                }
                .padding(20)
                .background(Color.white.opacity(0.6))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.roseLight, lineWidth: 1.5))
                .shadow(color: Theme.Colors.shadow, radius: 10)
            }
            .buttonStyle(.plain)

            if !touchID.errorMessage.isEmpty {
                Text(touchID.errorMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Gradients.background)
    }
}
