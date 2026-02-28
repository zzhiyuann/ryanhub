import Foundation
import UserNotifications
import UIKit

/// Manages local push notifications for proactive Facai messages and BOBO nudges.
/// Handles permission requests, notification scheduling, badge count, and deep link routing.
@MainActor
@Observable
final class NotificationManager: NSObject {
    // MARK: - State

    /// Whether the user has granted notification permission.
    var isAuthorized: Bool = false

    /// Number of pending (unread) notifications. Used for app icon badge count.
    var pendingNotificationCount: Int = 0

    /// Number of unread proactive messages from Facai while user was away from chat tab.
    /// Used for the in-app badge overlay on the chat tab icon.
    var unreadChatCount: Int = 0

    // MARK: - Init

    override init() {
        super.init()
        checkCurrentAuthorization()
    }

    // MARK: - Permission

    /// Request notification permission from the user. Call on first launch.
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let result = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        isAuthorized = result ?? false
    }

    /// Check current authorization status without prompting.
    func checkCurrentAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Send Notifications

    /// Schedule a local notification for a Facai assistant message.
    /// - Parameters:
    ///   - title: Notification title (e.g. "Facai" or the assistant name)
    ///   - body: The message content preview
    ///   - identifier: Unique ID for this notification (typically the message ID)
    func sendFacaiNotification(title: String, body: String, identifier: String) {
        guard isAuthorized else { return }

        pendingNotificationCount += 1
        unreadChatCount += 1

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: pendingNotificationCount)
        // Deep link info for routing on tap
        content.userInfo = ["destination": "chat", "messageId": identifier]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Schedule a local notification for a BOBO nudge.
    /// - Parameters:
    ///   - body: The nudge message text
    ///   - identifier: Unique ID for this notification
    func sendBoboNudge(body: String, identifier: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "BOBO"
        content.body = body
        content.sound = .default
        // Deep link to BOBO plugin in toolkit tab
        content.userInfo = ["destination": "bobo"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Badge Management

    /// Clear the app icon badge and reset unread counts.
    /// Call when the user opens the app or switches to the chat tab.
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
        pendingNotificationCount = 0
    }

    /// Clear the in-app chat tab badge count.
    /// Call when the user switches to the chat tab.
    func clearChatBadge() {
        unreadChatCount = 0
    }

    /// Clear both app icon badge and in-app chat badge.
    func clearAllBadges() {
        clearBadge()
        clearChatBadge()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Called when a notification is delivered while the app is in the foreground.
    /// We suppress the system banner (the message is already visible in-app).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show banner + sound even in foreground so proactive messages are noticed
        // when the user is on a different tab.
        return [.banner, .sound]
    }

    /// Called when the user taps a notification. Extract deep link info and post it.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let destination = userInfo["destination"] as? String else { return }

        let deepLink: DeepLink
        switch destination {
        case "chat":
            let messageId = userInfo["messageId"] as? String
            deepLink = .chat(messageId: messageId)
        case "bobo":
            deepLink = .bobo
        default:
            return
        }

        await MainActor.run {
            // Post the deep link through NotificationCenter for ContentView to handle
            NotificationCenter.default.post(
                name: .didReceiveDeepLink,
                object: nil,
                userInfo: ["deepLink": deepLink]
            )
        }
    }
}

// MARK: - Deep Link

/// Represents a navigation destination triggered by a notification tap.
enum DeepLink: Equatable {
    case chat(messageId: String?)
    case bobo
}

// MARK: - Notification Name

extension Notification.Name {
    /// Posted when a notification tap triggers a deep link navigation.
    static let didReceiveDeepLink = Notification.Name("com.ryanhub.didReceiveDeepLink")
}
