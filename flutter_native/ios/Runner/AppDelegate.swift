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
      let nativeCameraVC = NativeCameraViewController()
      nativeCameraVC.modalPresentationStyle = .fullScreen
      
      // Set up completion handler to get timing data
      nativeCameraVC.completionHandler = { [weak self] timingData in
        result(timingData)
      }
      
      controller.present(nativeCameraVC, animated: true)
    }
  }
}
