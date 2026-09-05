# The High-Performance Hybrid

A conference demo of adding Flutter feature screens to native apps. iOS has five tabs; the Android host deliberately implements Home and Game only.

| Tab | iOS | Android |
|---|---|---|
| Home | UIKit dashboard | Jetpack Compose dashboard |
| Web | Bundled, offline WKWebView settings + measured page cadence | — |
| Game | Flame Flappy Cat, route `/game` | Same Flutter game, route `/game` |
| Glass | Live-widget refraction shader, route `/glass` | — |
| Island | `flutter_scene` island, route `/scene` | — |

Each host owns one `FlutterEngineGroup`. Engines start on first tab selection and keep their state across tab switches. Hidden tabs pause their work. A native overlay shows host callback cadence, process memory, and per-engine Flutter UI/raster timing samples. The Web page has its own callback meter and an explicitly synthetic stress mode.

The metric definitions and shared names live in [ARCHITECTURE.md](docs/hybrid-demo/ARCHITECTURE.md). Build history and task notes are in [docs/hybrid-demo](docs/hybrid-demo/README.md); the current step is [08 — Stage-readiness](docs/hybrid-demo/08-polish.md).

## Toolchain and setup

- Flutter **3.47.2**, pinned by `.fvmrc`; use FVM for all module commands.
- iOS host deployment target **15.6**; Xcode with the appropriate iOS SDK and CocoaPods. Signing is needed to install on a phone.
- Android SDK **36**, minimum API **24**, Java **17+**, and a complete installed NDK. Gradle/AGP/Kotlin versions are pinned in `cool-android/`.

From the repo root:

```bash
fvm install
cd flutter_module
fvm flutter pub get
```

This regenerates the ignored `.ios/` and `.android/` embedding projects. The scene's build hook converts committed `assets/models/*.glb` files into generated bundled assets; no manual importer command is needed.

## Build iOS

```bash
# From the repo root:
cd flutter_module
fvm flutter build ios --config-only --release --target lib/main.dart
cd ../cool-ios
pod install
```

Open `cool-ios/cool-ios.xcworkspace`, choose the `cool-ios` scheme and a device, and use **Release** for the demo. The scheme's Run action defaults to Debug; change Run → Build Configuration in Edit Scheme before taking measurements.

For a compile/bundle check without device signing, from the repo root:

```bash
xcodebuild -workspace cool-ios/cool-ios.xcworkspace -scheme cool-ios \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Both `Info-Debug.plist` and `Info-Release.plist` already enable `FLTEnableFlutterGPU` and `CADisableMinimumFrameDurationOnPhone`. Do not add a new `Info.plist`.

After using `flutter run -t another_entrypoint.dart`, repeat the config-only command above. Flutter writes its target into `.ios/Flutter/flutter_export_environment.sh`, which the native build sources; a stale target can make every native Flutter tab launch the wrong screen.

## Build Android

Ensure `ANDROID_HOME` points to the installed SDK (or set `sdk.dir` in an untracked `cool-android/local.properties`), then:

```bash
# From the repo root, after flutter pub get:
cd cool-android
./gradlew :app:assembleRelease
# With the demo device connected:
./gradlew :app:installRelease
```

The APK is `cool-android/app/build/outputs/apk/release/app-release.apk`. This demo signs Release with the debug key for local installation. `ANDROID_NDK_VERSION` can select a complete installed NDK; otherwise the host discovers one under the configured SDK. INTERNET permission is restricted to Debug/Profile for the VM service. No runtime account or network is needed: enter any nonempty demo credentials at login.

## Develop and rehearse

```bash
cd flutter_module
fvm flutter run                         # existing standalone home at /
fvm flutter run --route=/game           # feature development
fvm flutter run --route=/glass
fvm flutter run --enable-flutter-gpu --route=/scene
fvm flutter analyze
fvm flutter test                        # existing checks
```

Use a physical device in profile mode for DevTools inspection, then a physical device in Release for stage numbers. Simulator/build success does not validate 120fps, thermal behavior, or memory claims. The native and Web page cadence readings can legitimately disagree; batch averages do not rule out individual slow frames.

Follow [08-polish.md](docs/hybrid-demo/08-polish.md) for the cold-launch, offline, tab-return and thermal rehearsal. Record results in [MEASUREMENTS.md](docs/hybrid-demo/MEASUREMENTS.md); measurements requiring a phone are still pending.

`flutter_native/` is the earlier reverse-direction camera demo. The previous talk script remains at `flutter_module/lib/couple.md`.

## Previous talk: iOS integration walkthrough

The original single-engine tutorial is retained below as historical reference. Its example app names and minimum versions are from that talk; use the toolchain and engine-group setup above for this project.

<details>
<summary>Original setup, presentation, and method-channel guide</summary>

This walkthrough demonstrates how to integrate a Flutter module into an existing iOS native application.

## Setup Instructions

### 1. Create Flutter Module

First, create a Flutter module using the module template:

```bash
flutter create --template module module_name
```

This creates a Flutter module that can be embedded into existing native applications.

### 2. Configure iOS Podfile

Navigate to your native iOS application's root directory and modify the `Podfile`:

```ruby
# Add this at the top of your Podfile
flutter_application_path = '../flutter_module'
load File.join(flutter_application_path, '.ios', 'Flutter', 'podhelper.rb')

target 'YourAppName' do
  use_frameworks!
  
  # Your existing pods...
  
  # Add Flutter integration
  install_all_flutter_pods(flutter_application_path)
end

# Add this at the bottom of your Podfile
post_install do |installer|
  flutter_post_install(installer) if defined?(flutter_post_install)
end
```

### 3. Install Flutter Pods

Run the following command in your iOS project directory:

```bash
pod install
```

### 4. Project Structure

Your project structure should look like this:

```
your-project/
├── ios-app/                 # Your native iOS app
│   ├── Podfile
│   ├── Podfile.lock
│   └── YourApp.xcworkspace
├── flutter_module/          # Flutter module
│   ├── lib/
│   ├── pubspec.yaml
│   └── .ios/
└── README.md
```

## Integration Steps

### 1. Import Flutter Engine

In your iOS app's `AppDelegate.swift`, import and initialize Flutter:

```swift
import Flutter
import FlutterPluginRegistrant

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    lazy var flutterEngine = FlutterEngine(name: "my flutter engine")
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Run the default Dart entrypoint with a default Flutter route.
        flutterEngine.run()
        // Connects plugins with iOS platform code to this app.
        GeneratedPluginRegistrant.register(with: self.flutterEngine)
        return true
    }
}
```

### 2. Present Flutter Screen

In your view controller, present the Flutter screen:

```swift
import Flutter

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func showFlutter(_ sender: Any) {
        let flutterEngine = (UIApplication.shared.delegate as! AppDelegate).flutterEngine
        let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
        present(flutterViewController, animated: true, completion: nil)
    }
}
```

### 3. Communication Between Native and Flutter

#### Method Channel Setup

In your Flutter module (`lib/main.dart`):

```dart
import 'package:flutter/services.dart';

class _MyHomePageState extends State<MyHomePage> {
  static const platform = MethodChannel('com.yourcompany.yourapp');
  
  // Send data to native
  Future<void> _sendDataToNative(String data) async {
    try {
      await platform.invokeMethod('methodName', data);
    } catch (e) {
      print("Failed to send data: $e");
    }
  }
  
  // Receive data from native
  Future<void> _receiveDataFromNative() async {
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'passDataFromNative':
          // Handle data from native
          break;
      }
    });
  }
}
```

In your iOS app:

```swift
import Flutter

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMethodChannel()
    }
    
    func setupMethodChannel() {
        let flutterEngine = (UIApplication.shared.delegate as! AppDelegate).flutterEngine
        let channel = FlutterMethodChannel(name: "com.yourcompany.yourapp", binaryMessenger: flutterEngine.binaryMessenger)
        
        channel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "methodName":
                // Handle call from Flutter
                result("Success")
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
```

## Project Features

This demo project includes:

- **Counter Demo**: Basic Flutter functionality with native communication
- **Visual Effects**: Water & sky shaders, rain effects, animated lists
- **Method Channel**: Bidirectional communication between Flutter and iOS

## Requirements

- Flutter SDK 3.0+
- iOS 11.0+
- Xcode 12.0+
- CocoaPods 1.10.0+

## Troubleshooting

### Common Issues

1. **Build Errors**: Make sure Flutter is properly installed and in your PATH
2. **Pod Install Fails**: Check that the Flutter module path is correct in Podfile
3. **Runtime Errors**: Ensure FlutterEngine is properly initialized in AppDelegate

### Clean Build

If you encounter issues, try cleaning and rebuilding:

```bash
# Clean Flutter
cd flutter_module
flutter clean
flutter pub get

# Clean iOS
cd ../ios-app
pod deintegrate
pod install
```

## Resources

- [Flutter Add-to-App Documentation](https://docs.flutter.dev/development/add-to-app)
- [Method Channels Documentation](https://docs.flutter.dev/development/platform-integration/platform-channels)
- [Flutter iOS Integration Guide](https://docs.flutter.dev/development/add-to-app/ios/project-setup)

</details>
