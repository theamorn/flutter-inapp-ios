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

    // UI Elements - Programmatic
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private let usernameTextField = UITextField()
    private let passwordTextField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let flutterButton = UIButton(type: .system)
    
    private let statusLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start Flutter Engine
        flutterEngine.run()
        
        setupUI()
        setupConstraints()
        setupActions()
        setupTapGesture()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Setup gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemBlue.withAlphaComponent(0.1).cgColor,
            UIColor.systemPurple.withAlphaComponent(0.1).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        // Setup logo
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.image = UIImage(systemName: "app.badge.fill")
        logoImageView.tintColor = .systemBlue
        logoImageView.contentMode = .scaleAspectFit
        contentView.addSubview(logoImageView)
        
        // Setup title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Welcome Back"
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        contentView.addSubview(titleLabel)
        
        // Setup subtitle
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Sign in to continue to Flutter Demo"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        contentView.addSubview(subtitleLabel)
        
        // Setup username field
        setupTextField(usernameTextField, placeholder: "Username", isSecure: false)
        
        // Setup password field
        setupTextField(passwordTextField, placeholder: "Password", isSecure: true)
        
        // Setup login button
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        loginButton.setTitle("Sign In", for: .normal)
        loginButton.backgroundColor = .systemBlue
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        loginButton.layer.cornerRadius = 12
        loginButton.layer.shadowColor = UIColor.systemBlue.cgColor
        loginButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        loginButton.layer.shadowOpacity = 0.3
        loginButton.layer.shadowRadius = 8
        contentView.addSubview(loginButton)
        
        // Setup Flutter button
        flutterButton.translatesAutoresizingMaskIntoConstraints = false
        flutterButton.setTitle("🚀 Launch Flutter Demo", for: .normal)
        flutterButton.backgroundColor = .systemPurple
        flutterButton.setTitleColor(.white, for: .normal)
        flutterButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        flutterButton.layer.cornerRadius = 12
        flutterButton.layer.borderWidth = 2
        flutterButton.layer.borderColor = UIColor.systemPurple.cgColor
        contentView.addSubview(flutterButton)
        
        // Setup status label
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Ready to connect with Flutter"
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.backgroundColor = UIColor.secondarySystemBackground
        statusLabel.layer.cornerRadius = 8
        statusLabel.layer.masksToBounds = true
        statusLabel.isHidden = true
        contentView.addSubview(statusLabel)
    }
    
    private func setupTextField(_ textField: UITextField, placeholder: String, isSecure: Bool) {
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = placeholder
        textField.isSecureTextEntry = isSecure
        textField.borderStyle = .none
        textField.backgroundColor = UIColor.secondarySystemBackground
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.separator.cgColor
        textField.font = UIFont.systemFont(ofSize: 16)
        
        // Add padding
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: textField.frame.height))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        
        // Add icon
        let iconName = isSecure ? "lock.fill" : "person.fill"
        let iconView = UIImageView(image: UIImage(systemName: iconName))
        iconView.tintColor = .systemGray
        iconView.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        let iconContainer = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 20))
        iconContainer.addSubview(iconView)
        iconView.center = iconContainer.center
        textField.leftView = iconContainer
        
        contentView.addSubview(textField)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Logo
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 60),
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            
            // Username field
            usernameTextField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 48),
            usernameTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            usernameTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            usernameTextField.heightAnchor.constraint(equalToConstant: 56),
            
            // Password field
            passwordTextField.topAnchor.constraint(equalTo: usernameTextField.bottomAnchor, constant: 16),
            passwordTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            passwordTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            passwordTextField.heightAnchor.constraint(equalToConstant: 56),
            
            // Login button
            loginButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 32),
            loginButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            loginButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            loginButton.heightAnchor.constraint(equalToConstant: 56),
            
            // Flutter button
            flutterButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 16),
            flutterButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            flutterButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            flutterButton.heightAnchor.constraint(equalToConstant: 56),
            
            // Status label
            statusLabel.topAnchor.constraint(equalTo: flutterButton.bottomAnchor, constant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
            statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
    }
    
    private func setupActions() {
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        flutterButton.addTarget(self, action: #selector(submitRequest), for: .touchUpInside)
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func loginButtonTapped() {
        // Add button animation
        UIView.animate(withDuration: 0.1, animations: {
            self.loginButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.loginButton.transform = CGAffineTransform.identity
            }
        }
        
        // Simple validation
        guard let username = usernameTextField.text, !username.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "Error", message: "Please fill in all fields")
            return
        }
        
        // Simulate login success
        showAlert(title: "Success", message: "Welcome, \(username)!")
    }
    
    @objc private func submitRequest() {
        let passValue = usernameTextField.text ?? ""
        print("Submit Button and Send data to Flutter: \(passValue)")
        
        // Add button animation
        UIView.animate(withDuration: 0.1, animations: {
            self.flutterButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.flutterButton.transform = CGAffineTransform.identity
            }
        }
        
        // Add This code to connect to FlutterViewController
        let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
        let channel = FlutterMethodChannel(name: "com.theamorn.flutter", binaryMessenger: flutterViewController.binaryMessenger)
        
        // For Passing Data
        channel.invokeMethod("passValueFromNative", arguments: passValue)

        // Receive data from Flutter
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "getValueFromFlutter" {
                if let value = call.arguments as? Int {
                    DispatchQueue.main.async {
                        self?.statusLabel.text = "✅ Received from Flutter: \(value)"
                        self?.statusLabel.isHidden = false
                        self?.statusLabel.textColor = .systemGreen
                    }
                    flutterViewController.dismiss(animated: true)
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        flutterViewController.modalPresentationStyle = .fullScreen
        present(flutterViewController, animated: true , completion: nil)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
