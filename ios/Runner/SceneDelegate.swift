import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  static let tapUrlKey = "flutter.sb_tap_return"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    if let response = connectionOptions.notificationResponse,
       let url = SceneDelegate.extractDestination(
         from: response.notification.request.content.userInfo
       )
    {
      SceneDelegate.persist(url: url)
    }
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    super.scene(scene, continue: userActivity)
  }

  static func extractDestination(from userInfo: [AnyHashable: Any]) -> String? {
    let candidateKeys = ["url", "link", "target", "deeplink", "deep_link"]

    func lookup(_ map: [AnyHashable: Any]) -> String? {
      for key in candidateKeys {
        if let raw = map[key] as? String {
          let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
          if !trimmed.isEmpty { return trimmed }
        }
      }
      return nil
    }

    if let direct = lookup(userInfo) { return direct }
    if let nested = userInfo["data"] as? [AnyHashable: Any],
       let url = lookup(nested) { return url }
    if let nested = userInfo["payload"] as? [AnyHashable: Any],
       let url = lookup(nested) { return url }
    return nil
  }

  static func persist(url: String) {
    let d = UserDefaults.standard
    d.set(url, forKey: tapUrlKey)
    d.synchronize()
  }
}
