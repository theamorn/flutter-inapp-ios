import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let cameraChannel = FlutterMethodChannel(
      name: "com.theamorn.camera",
      binaryMessenger: controller.binaryMessenger)

    cameraChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      // This method is invoked on the UI thread.
      guard call.method == "openNativeCamera" else {
        result(FlutterMethodNotImplemented)
        return
      }

      self.openNativeCamera(result: result, controller: controller)
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func openNativeCamera(result: @escaping FlutterResult, controller: FlutterViewController)
  {
    DispatchQueue.main.async {
      // For now, let's test with a simple alert to ensure the method channel works
      let alert = UIAlertController(
        title: "Native Camera", message: "This would open the native camera implementation",
        preferredStyle: .alert)
      alert.addAction(
        UIAlertAction(title: "OK", style: .default) { _ in
          // Try to create the camera view controller
          let nativeCameraVC = NativeCameraViewController()
          nativeCameraVC.modalPresentationStyle = .fullScreen
          controller.present(nativeCameraVC, animated: true)
        })
      alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

      controller.present(alert, animated: true)
      result("Native camera dialog opened successfully")
    }
  }
}
