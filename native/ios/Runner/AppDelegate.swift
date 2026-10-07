import Flutter
import UIKit
import UserNotifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "vn.mpwindows.crm/native"
  private let appGroupIdentifier = "group.vn.mpwindows.crm"
  private let widgetKind = "MPWindowsTodayWidget"

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "NATIVE_UNAVAILABLE", message: "Native bridge unavailable.", details: nil))
        return
      }

      switch call.method {
      case "requestNotificationPermission":
        self.requestNotificationPermission(result: result)
      case "syncReminders":
        self.syncReminders(call: call, result: result)
      case "updateWidget":
        self.updateWidget(call: call, result: result)
      case "setBadgeCount":
        self.setBadgeCount(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func requestNotificationPermission(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
      granted, error in
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(
            code: "NOTIFICATION_PERMISSION",
            message: error.localizedDescription,
            details: nil
          ))
        } else {
          result(granted)
        }
      }
    }
  }

  private func syncReminders(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let items = arguments["items"] as? [[String: Any]]
    else {
      result(FlutterError(code: "BAD_ARGUMENTS", message: "Missing reminder items.", details: nil))
      return
    }

    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
      let managed = requests
        .map(\.identifier)
        .filter { $0.hasPrefix("mpw.") }
      center.removePendingNotificationRequests(withIdentifiers: managed)

      let group = DispatchGroup()
      let lock = NSLock()
      var scheduled = 0
      var firstError: Error?

      for item in items.prefix(60) {
        guard
          let identifier = item["id"] as? String,
          let title = item["title"] as? String,
          let body = item["body"] as? String,
          let milliseconds = item["fireAt"] as? NSNumber
        else { continue }

        let fireDate = Date(timeIntervalSince1970: milliseconds.doubleValue / 1000.0)
        guard fireDate > Date() else { continue }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["mpwindowsReminderId": identifier]

        let components = Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute, .second],
          from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
          identifier: identifier,
          content: content,
          trigger: trigger
        )

        group.enter()
        center.add(request) { error in
          lock.lock()
          if let error, firstError == nil {
            firstError = error
          }
          if error == nil {
            scheduled += 1
          }
          lock.unlock()
          group.leave()
        }
      }

      group.notify(queue: .main) {
        if let firstError {
          result(FlutterError(
            code: "SCHEDULE_FAILED",
            message: firstError.localizedDescription,
            details: ["scheduled": scheduled]
          ))
        } else {
          result(scheduled)
        }
      }
    }
  }

  private func setBadgeCount(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let countNumber = arguments["count"] as? NSNumber
    else {
      result(FlutterError(code: "BAD_ARGUMENTS", message: "Missing badge count.", details: nil))
      return
    }

    let count = max(0, countNumber.intValue)
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      guard settings.badgeSetting == .enabled else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "BADGE_DISABLED",
            message: "Badges are disabled for MPWindowsCRM in iOS notification settings.",
            details: nil
          ))
        }
        return
      }

      if #available(iOS 16.0, *) {
        center.setBadgeCount(count) { error in
          DispatchQueue.main.async {
            if let error {
              result(FlutterError(code: "BADGE_FAILED", message: error.localizedDescription, details: nil))
            } else {
              result(true)
            }
          }
        }
      } else {
        DispatchQueue.main.async {
          UIApplication.shared.applicationIconBadgeNumber = count
          result(true)
        }
      }
    }
  }

  private func updateWidget(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let data = arguments["data"] as? [String: Any]
    else {
      result(FlutterError(code: "BAD_ARGUMENTS", message: "Missing widget data.", details: nil))
      return
    }

    guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
      result(FlutterError(code: "APP_GROUP", message: "App Group is unavailable.", details: nil))
      return
    }

    do {
      let encoded = try JSONSerialization.data(withJSONObject: data, options: [])
      defaults.set(encoded, forKey: "mpwindows_widget_payload")
      defaults.set(Date().timeIntervalSince1970, forKey: "mpwindows_widget_updated_at")

      if #available(iOS 14.0, *) {
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
      }
      result(true)
    } catch {
      result(FlutterError(code: "WIDGET_DATA", message: error.localizedDescription, details: nil))
    }
  }
}
