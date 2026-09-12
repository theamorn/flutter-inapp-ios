//
//  LoginViewController.swift
//  cool-ios
//
//  Created by Amorn Apichattanakul on 21/11/2567 BE.
//

import UIKit

final class LoginViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let logoBackgroundView = UIView()
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let meetupChip = UILabel()
    private let subtitleLabel = UILabel()
    private let formCard = UIView()

    private let usernameTextField = UITextField()
    private let passwordTextField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let gradientLayer = CAGradientLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        setupTapGesture()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        gradientLayer.colors = [
            UIColor.systemBlue.withAlphaComponent(0.28).cgColor,
            UIColor.systemPurple.withAlphaComponent(0.22).cgColor,
            UIColor.systemBackground.cgColor,
        ]
        gradientLayer.locations = [0.0, 0.45, 1.0]
        view.layer.insertSublayer(gradientLayer, at: 0)

        logoBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        logoBackgroundView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.14)
        logoBackgroundView.layer.cornerRadius = 44
        contentView.addSubview(logoBackgroundView)

        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.image = UIImage(systemName: "person.3.fill")
        logoImageView.tintColor = .systemBlue
        logoImageView.contentMode = .scaleAspectFit
        logoBackgroundView.addSubview(logoImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Mobile Native Meetup"
        titleLabel.font = .systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        contentView.addSubview(titleLabel)

        meetupChip.translatesAutoresizingMaskIntoConstraints = false
        meetupChip.text = "Meetup"
        meetupChip.font = .systemFont(ofSize: 13, weight: .semibold)
        meetupChip.textColor = .systemPurple
        meetupChip.textAlignment = .center
        meetupChip.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.14)
        meetupChip.layer.cornerRadius = 12
        meetupChip.clipsToBounds = true
        contentView.addSubview(meetupChip)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Sign in to continue to Flutter Demo"
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        contentView.addSubview(subtitleLabel)

        formCard.translatesAutoresizingMaskIntoConstraints = false
        formCard.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.92)
        formCard.layer.cornerRadius = 20
        formCard.layer.shadowColor = UIColor.black.cgColor
        formCard.layer.shadowOpacity = 0.08
        formCard.layer.shadowOffset = CGSize(width: 0, height: 8)
        formCard.layer.shadowRadius = 16
        contentView.addSubview(formCard)

        setupTextField(usernameTextField, placeholder: "Username", isSecure: false)
        usernameTextField.textContentType = .username
        setupTextField(passwordTextField, placeholder: "Password", isSecure: true)
        passwordTextField.textContentType = .password

        loginButton.translatesAutoresizingMaskIntoConstraints = false
        loginButton.setTitle("Sign In", for: .normal)
        loginButton.backgroundColor = .systemBlue
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        loginButton.layer.cornerRadius = 12
        loginButton.layer.shadowColor = UIColor.systemBlue.cgColor
        loginButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        loginButton.layer.shadowOpacity = 0.3
        loginButton.layer.shadowRadius = 8
        formCard.addSubview(loginButton)
    }

    private func setupTextField(
        _ textField: UITextField,
        placeholder: String,
        isSecure: Bool
    ) {
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = placeholder
        textField.isSecureTextEntry = isSecure
        textField.borderStyle = .none
        textField.backgroundColor = .tertiarySystemBackground
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.separator.cgColor
        textField.font = .systemFont(ofSize: 16)

        let iconName = isSecure ? "lock.fill" : "person.fill"
        let iconView = UIImageView(image: UIImage(systemName: iconName))
        iconView.tintColor = .systemGray
        iconView.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        let iconContainer = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 20))
        iconContainer.addSubview(iconView)
        iconView.center = iconContainer.center
        textField.leftView = iconContainer
        textField.leftViewMode = .always

        formCard.addSubview(textField)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            logoBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 52),
            logoBackgroundView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoBackgroundView.widthAnchor.constraint(equalToConstant: 88),
            logoBackgroundView.heightAnchor.constraint(equalToConstant: 88),

            logoImageView.centerXAnchor.constraint(equalTo: logoBackgroundView.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: logoBackgroundView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 44),
            logoImageView.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.topAnchor.constraint(equalTo: logoBackgroundView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            meetupChip.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            meetupChip.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            meetupChip.widthAnchor.constraint(equalToConstant: 88),
            meetupChip.heightAnchor.constraint(equalToConstant: 24),

            subtitleLabel.topAnchor.constraint(equalTo: meetupChip.bottomAnchor, constant: 10),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            formCard.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            formCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            formCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            formCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -48),

            usernameTextField.topAnchor.constraint(equalTo: formCard.topAnchor, constant: 20),
            usernameTextField.leadingAnchor.constraint(equalTo: formCard.leadingAnchor, constant: 16),
            usernameTextField.trailingAnchor.constraint(equalTo: formCard.trailingAnchor, constant: -16),
            usernameTextField.heightAnchor.constraint(equalToConstant: 56),

            passwordTextField.topAnchor.constraint(equalTo: usernameTextField.bottomAnchor, constant: 14),
            passwordTextField.leadingAnchor.constraint(equalTo: formCard.leadingAnchor, constant: 16),
            passwordTextField.trailingAnchor.constraint(equalTo: formCard.trailingAnchor, constant: -16),
            passwordTextField.heightAnchor.constraint(equalToConstant: 56),

            loginButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 24),
            loginButton.leadingAnchor.constraint(equalTo: formCard.leadingAnchor, constant: 16),
            loginButton.trailingAnchor.constraint(equalTo: formCard.trailingAnchor, constant: -16),
            loginButton.heightAnchor.constraint(equalToConstant: 56),
            loginButton.bottomAnchor.constraint(equalTo: formCard.bottomAnchor, constant: -20),
        ])
    }

    private func setupActions() {
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        usernameTextField.addTarget(self, action: #selector(textFieldDidSubmit), for: .editingDidEndOnExit)
        passwordTextField.addTarget(self, action: #selector(textFieldDidSubmit), for: .editingDidEndOnExit)
    }

    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func textFieldDidSubmit(_ sender: UITextField) {
        if sender === usernameTextField {
            passwordTextField.becomeFirstResponder()
        } else {
            loginButtonTapped()
        }
    }

    @objc private func loginButtonTapped() {
        UIView.animate(withDuration: 0.1, animations: {
            self.loginButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.loginButton.transform = .identity
            }
        }

        guard usernameTextField.text?.isEmpty == false,
              passwordTextField.text?.isEmpty == false else {
            showAlert(title: "Error", message: "Please fill in all fields")
            return
        }

        view.endEditing(true)
        guard let window = view.window else { return }
        UIView.transition(
            with: window,
            duration: 0.3,
            options: [.transitionCrossDissolve, .allowAnimatedContent],
            animations: {
                window.rootViewController = MainTabBarController()
            }
        )
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
