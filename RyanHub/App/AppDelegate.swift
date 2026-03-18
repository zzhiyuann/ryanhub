import UIKit
import UserNotifications

/// AppDelegate handles APNs device token registration and remote notification delivery.
/// SwiftUI uses @UIApplicationDelegateAdaptor to bridge this into the app lifecycle.
final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Stored device token (hex string) for APNs push notifications.
    static var deviceToken: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register for remote push notifications
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Self.deviceToken = token
        print("[APNs] Device token: \(token)")
        // Send token to our bridge server
        Task { await Self.registerTokenWithServer(token) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Registration failed: \(error.localizedDescription)")
    }

    /// Send the APNs device token to the bridge server so it can send push notifications.
    private static func registerTokenWithServer(_ token: String) async {
        let baseURL = UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? AppState.defaultFoodAnalysisURL

        guard let url = URL(string: "\(baseURL)/apns/register") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["token": token])
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                print("[APNs] Token registered with server")
            }
        } catch {
            print("[APNs] Token registration failed: \(error.localizedDescription)")
        }
    }
}
