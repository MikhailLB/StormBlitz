import UserNotifications

/// Notification Service Extension — downloads and attaches rich media images
/// to push notifications before iOS displays them.
///
/// Requirements (backend side):
///   • APS payload must include "mutable-content": 1
///   • Image URL must be present in one of the supported fields (see below)
///
/// Supported image URL locations (checked in order):
///   1. userInfo["fcm_options"]["image"]   — standard FCM v1 image field
///   2. userInfo["image"]                  — flat data-payload field
///   3. userInfo["gcm.notification.image"] — legacy FCM image field
///   4. userInfo["media-url"]              — generic media field
///   5. userInfo["attachment-url"]         — alternative generic field
class NotificationService: UNNotificationServiceExtension {

  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttemptContent: UNMutableNotificationContent?
  private var downloadTask: URLSessionDataTask?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
      contentHandler(request.content)
      return
    }
    self.bestAttemptContent = content

    guard let imageUrl = extractImageUrl(from: request.content.userInfo) else {
      contentHandler(content)
      return
    }

    attachImage(from: imageUrl, to: content, completion: contentHandler)
  }

  override func serviceExtensionTimeWillExpire() {
    downloadTask?.cancel()
    if let handler = contentHandler, let content = bestAttemptContent {
      handler(content)
    }
  }

  // MARK: - Private

  private func extractImageUrl(from userInfo: [AnyHashable: Any]) -> URL? {
    let candidates: [String?] = [
      (userInfo["fcm_options"] as? [String: Any])?["image"] as? String,
      userInfo["image"] as? String,
      userInfo["gcm.notification.image"] as? String,
      userInfo["media-url"] as? String,
      userInfo["attachment-url"] as? String,
    ]
    for candidate in candidates {
      if let raw = candidate,
         !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
         let url = URL(string: raw) {
        return url
      }
    }
    return nil
  }

  private func attachImage(
    from url: URL,
    to content: UNMutableNotificationContent,
    completion: @escaping (UNNotificationContent) -> Void
  ) {
    let ext = url.pathExtension.lowercased()
    let allowedExtensions = ["jpg", "jpeg", "png", "gif", "webp"]
    let fileExtension = allowedExtensions.contains(ext) ? ext : "jpg"

    let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
    let tmpFile = tmpDir
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(fileExtension)

    downloadTask = URLSession.shared.dataTask(with: url) { data, response, _ in
      defer { completion(content) }
      guard let data = data, !data.isEmpty else { return }
      do {
        try data.write(to: tmpFile, options: .atomic)
        let attachment = try UNNotificationAttachment(
          identifier: "rich-image",
          url: tmpFile,
          options: nil
        )
        content.attachments = [attachment]
      } catch {}
    }
    downloadTask?.resume()
  }
}
