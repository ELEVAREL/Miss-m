import SwiftUI
import UserNotifications

// MARK: - Miss M Notification System
// Animated toast-style notifications that slide in from the top

struct MissMNotification: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
    let style: Style
    let duration: TimeInterval

    enum Style {
        case info      // Rose accent
        case success   // Green accent
        case warning   // Orange accent
        case reminder  // Gold accent
        case health    // Teal accent

        var color: Color {
            switch self {
            case .info: return Theme.Colors.rosePrimary
            case .success: return Color(hex: "#26A69A")
            case .warning: return Color(hex: "#FF9800")
            case .reminder: return Theme.Colors.gold
            case .health: return Color(hex: "#00B0FF")
            }
        }
    }

    init(icon: String, title: String, message: String, style: Style = .info, duration: TimeInterval = 4) {
        self.icon = icon; self.title = title; self.message = message
        self.style = style; self.duration = duration
    }

    static func == (lhs: MissMNotification, rhs: MissMNotification) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Notification Manager

@Observable
class NotificationManager {
    static let shared = NotificationManager()
    var current: MissMNotification?
    var isShowing = false
    private var dismissTask: Task<Void, Never>?

    private init() {
        // Request notification permission on init
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func show(_ notification: MissMNotification) {
        // Fire real macOS notification
        sendSystemNotification(title: notification.title, body: notification.message, icon: notification.icon)
        dismissTask?.cancel()
        current = notification

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isShowing = true
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(notification.duration))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    func dismiss() {
        withAnimation(.easeIn(duration: 0.25)) {
            isShowing = false
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            current = nil
        }
    }

    // Convenience methods
    func info(_ title: String, message: String, icon: String = "\u{2728}") {
        show(MissMNotification(icon: icon, title: title, message: message, style: .info))
    }

    func success(_ title: String, message: String, icon: String = "\u{2705}") {
        show(MissMNotification(icon: icon, title: title, message: message, style: .success))
    }

    func reminder(_ title: String, message: String, icon: String = "\u{1F514}") {
        show(MissMNotification(icon: icon, title: title, message: message, style: .reminder))
    }

    func health(_ title: String, message: String, icon: String = "\u{2764}\u{FE0F}") {
        show(MissMNotification(icon: icon, title: title, message: message, style: .health))
    }

    // MARK: - macOS System Notification
    private func sendSystemNotification(title: String, body: String, icon: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(icon) Miss M"
        content.subtitle = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Fire immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Notification Toast View

struct NotificationToast: View {
    let notification: MissMNotification
    @State private var pulseIcon = false

    var body: some View {
        HStack(spacing: 10) {
            // Animated icon
            Text(notification.icon)
                .font(.system(size: 20))
                .scaleEffect(pulseIcon ? 1.1 : 0.9)
                .animation(.easeInOut(duration: 0.6).repeatCount(2, autoreverses: true), value: pulseIcon)

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(notification.message)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textMedium)
                    .lineLimit(2)
            }

            Spacer()

            // Dismiss button
            Button(action: { NotificationManager.shared.dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Theme.Colors.textXSoft)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                Color.white.opacity(0.95)
                // Accent color bar on left
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(notification.style.color)
                        .frame(width: 3)
                    Spacer()
                }
            }
        )
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(notification.style.color.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: notification.style.color.opacity(0.15), radius: 12, x: 0, y: 6)
        .onAppear { pulseIcon = true }
    }
}

// MARK: - Notification Overlay Modifier

struct NotificationOverlayModifier: ViewModifier {
    let manager = NotificationManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if manager.isShowing, let notification = manager.current {
                    NotificationToast(notification: notification)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(999)
                }
            }
    }
}

extension View {
    func withNotifications() -> some View {
        modifier(NotificationOverlayModifier())
    }
}
