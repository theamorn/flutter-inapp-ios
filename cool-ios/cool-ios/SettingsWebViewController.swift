//
//  SettingsWebViewController.swift
//  cool-ios
//

import UIKit
import WebKit

final class SettingsWebViewController: UIViewController {
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .systemGroupedBackground
        webView.scrollView.backgroundColor = .systemGroupedBackground
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        return webView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = .systemGroupedBackground

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        loadBundledSettings()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The bundled page owns its sticky translucent title bar.
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func loadBundledSettings() {
        guard let url = Bundle.main.url(forResource: "settings", withExtension: "html") else {
            showLoadError()
            return
        }

        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    private func showLoadError() {
        let errorLabel = UILabel()
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.text = "Settings couldn't be loaded.\nThe bundled settings.html resource is missing."
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.font = .preferredFont(forTextStyle: .body)
        errorLabel.textColor = .secondaryLabel
        view.addSubview(errorLabel)

        NSLayoutConstraint.activate([
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),
        ])

        assertionFailure("settings.html must be included in the cool-ios target's Copy Bundle Resources phase")
    }
}

extension SettingsWebViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // The conference demo is intentionally self-contained. The initial file
        // navigation and same-document jumps are allowed; everything else stays
        // offline even if content is changed later.
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let isLocalFile = url.isFileURL
        let isSameDocument = navigationAction.navigationType == .linkActivated && url.fragment != nil
        decisionHandler(isLocalFile || isSameDocument ? .allow : .cancel)
    }
}
