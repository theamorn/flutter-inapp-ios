//
//  ViewController.swift
//  cool-ios
//
//  Created by Amorn Apichattanakul on 21/11/2567 BE.
//

import UIKit
import Flutter

class ViewController: UIViewController {
    lazy var flutterEngine: FlutterEngine = FlutterEngine(name: "my engine")

    @IBOutlet weak var passValueTextField: UITextField!
    @IBOutlet weak var infoLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start Futter Engine
        flutterEngine.run()
    }

    @IBAction func submitRequest(_ sender: UIButton) {
        let passValue = passValueTextField.text ?? ""
        print("Submit Button and Send data to Flutter: \(passValue)")
        let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
        let channel = FlutterMethodChannel(name: "com.theamorn.flutter", binaryMessenger: flutterViewController.binaryMessenger)
        
        // For Passing Data
        channel.invokeMethod("passValueFromNative", arguments: passValue)

        // Recieve data when Flutter
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "getValueFromFlutter" {
                if let value = call.arguments as? Int {
                    self?.infoLabel.text = "Receive Data From Flutter: \(value)"
                    flutterViewController.dismiss(animated: true)
                }
                
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        flutterViewController.modalPresentationStyle = .fullScreen
        present(flutterViewController, animated: true , completion: nil)
    }
    
}
