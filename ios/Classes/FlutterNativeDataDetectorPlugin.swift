import Flutter
import Foundation

public class FlutterNativeDataDetectorPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flutter_native_data_detector",
      binaryMessenger: registrar.messenger()
    )
    let instance = FlutterNativeDataDetectorPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    // No-op on iOS — NSDataDetector requires no model download.
    // The `language` argument exists for API parity with Android and is ignored.
    case "prepareModel":
      result(true)

    // NSDataDetector is always available, so the model is always ready.
    case "getModelStatus":
      result("ready")

    case "detect":
      guard
        let args = call.arguments as? [String: Any],
        let text = args["text"] as? String,
        let types = args["types"] as? [String]
      else {
        result(FlutterError(
          code: "BAD_ARGS",
          message: "detect expects {text: String, types: [String]}",
          details: nil
        ))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        let entities = Self.detect(in: text, types: types)
        DispatchQueue.main.async { result(entities) }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func detect(in text: String, types: [String]) -> [[String: Any]] {
    var checkingTypes: NSTextCheckingResult.CheckingType = []

    for type in types {
      switch type {
      case "phoneNumber":
        checkingTypes.insert(.phoneNumber)
      case "link", "email":
        checkingTypes.insert(.link)
      case "address":
        checkingTypes.insert(.address)
      case "date":
        checkingTypes.insert(.date)
      default:
        break
      }
    }

    guard let detector = try? NSDataDetector(types: checkingTypes.rawValue) else {
      return []
    }

    let range = NSRange(text.startIndex..., in: text)
    let matches = detector.matches(in: text, options: [], range: range)

    var results: [[String: Any]] = []

    for match in matches {
      guard let matchRange = Range(match.range, in: text) else { continue }
      let matchedText = String(text[matchRange])

      var type: String
      var data: [String: String] = [:]

      switch match.resultType {
      case .phoneNumber:
        guard types.contains("phoneNumber") else { continue }
        type = "phoneNumber"
        if let phone = match.phoneNumber {
          data["phoneNumber"] = phone
        }

      case .link:
        guard let url = match.url else { continue }
        if url.scheme == "mailto" {
          guard types.contains("email") else { continue }
          type = "email"
          data["email"] = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
        } else {
          guard types.contains("link") else { continue }
          type = "link"
          data["url"] = url.absoluteString
        }

      case .address:
        guard types.contains("address") else { continue }
        type = "address"
        if let components = match.addressComponents {
          if let street = components[.street] { data["street"] = street }
          if let city = components[.city] { data["city"] = city }
          if let state = components[.state] { data["state"] = state }
          if let zip = components[.zip] { data["zip"] = zip }
          if let country = components[.country] { data["country"] = country }
        }

      case .date:
        guard types.contains("date") else { continue }
        type = "date"
        if let date = match.date {
          let formatter = ISO8601DateFormatter()
          data["date"] = formatter.string(from: date)
        }

      default:
        continue
      }

      // NSRange offsets are UTF-16 code units, which is also what Dart string
      // indices are — so start/end align with the Dart string (and Android's
      // ML Kit char offsets).
      let start = match.range.location
      let end = match.range.location + match.range.length

      results.append([
        "type": type,
        "text": matchedText,
        "start": start,
        "end": end,
        "data": data,
      ])
    }

    return results
  }
}
