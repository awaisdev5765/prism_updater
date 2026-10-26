import Flutter
import UIKit
import StoreKit

/**
 * iOS side of prism_updater's native store flow.
 *
 * Presents SKStoreProductViewController for the configured Apple ID so the
 * user can update without leaving the app. Falls back to opening the App
 * Store URL when no Apple ID is provided or the sheet cannot load.
 */
public class PrismUpdaterPlugin: NSObject, FlutterPlugin, SKStoreProductViewControllerDelegate {
    private static var appleId: String?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "prism_updater/store_flow", binaryMessenger: registrar.messenger())
        let instance = PrismUpdaterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "launchStore":
            guard let args = call.arguments as? [String: Any],
                  let appleId = args["appleId"] as? String, !appleId.isEmpty else {
                result("unavailable")
                return
            }
            Self.appleId = appleId
            DispatchQueue.main.async {
                self.presentStoreSheet(appleId: appleId, result: result)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func presentStoreSheet(appleId: String, result: @escaping FlutterResult) {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .last else {
            result("failed")
            return
        }

        let storeViewController = SKStoreProductViewController()
        storeViewController.delegate = self
        storeViewController.loadProduct(
            withParameters: [SKStoreProductParameterITunesItemIdentifier: appleId]
        ) { loaded, _ in
            if loaded {
                rootViewController.present(storeViewController, animated: true)
                result("launched")
            } else {
                result("failed")
            }
        }
    }

    public func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        viewController.dismiss(animated: true)
    }
}
