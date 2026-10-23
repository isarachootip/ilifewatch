import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var veepoo: VeepooBridge?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        if let registrar = self.registrar(forPlugin: "VeepooBridge") {
            veepoo = VeepooBridge(messenger: registrar.messenger())
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
