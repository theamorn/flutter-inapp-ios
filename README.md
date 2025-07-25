# Flutter In-App iOS Integration

This project demonstrates how to integrate a Flutter module into an existing iOS native application.

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
