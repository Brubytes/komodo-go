import Flutter
import UIKit

/// Reports the system's vertical bar edge and the occluded (status bar /
/// camera) regions to Dart (iOS 27.1+, e.g. the foldable iPhone's inner
/// display). Dart polls it whenever the window metrics change, which covers
/// fold/unfold and rotation; older systems answer "none".
final class VerticalBarBridge {
  static let channelName = "app.komodo_go/vertical_bar"

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "getInfo" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(currentInfo())
    }
  }

  private static func currentInfo() -> [String: Any] {
    let none: [String: Any] = ["edge": "none", "occluded": [[Double]]()]
    guard #available(iOS 27.1, *) else { return none }

    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
      ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    guard let view = scene?.keyWindow?.rootViewController?.view else { return none }

    let edge: String
    switch view.traitCollection.verticalBarEdge {
    case .leading: edge = "leading"
    case .trailing: edge = "trailing"
    default: edge = "none"
    }

    // [x, y, width, height] in the root view's coordinate space (points).
    let occluded = view.reservedRegions(kind: .occlusion)
      .filter { $0.isActive }
      .map { region -> [Double] in
        let f = region.frame
        return [Double(f.origin.x), Double(f.origin.y), Double(f.width), Double(f.height)]
      }
    return ["edge": edge, "occluded": occluded]
  }
}
