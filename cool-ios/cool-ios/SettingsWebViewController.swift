//
//  SettingsWebViewController.swift
//  cool-ios
//

import UIKit
import WebKit

final class SettingsWebViewController: UIViewController {
    private var pageVisible = false
    private var loadErrorLabel: UILabel?
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
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
        pageVisible = true
        updatePageActivity()
        // The bundled page owns its sticky translucent title bar.
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pageVisible = false
        updatePageActivity()
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func loadBundledSettings() {
        guard let url = Bundle.main.url(forResource: "settings", withExtension: "html") else {
            showLoadError()
            return
        }

        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    private func updatePageActivity() {
        webView.evaluateJavaScript("window.setDemoActive?.(\(pageVisible))", completionHandler: nil)
    }

    private func showLoadError(_ message: String = "The bundled settings.html resource is missing.") {
        loadErrorLabel?.removeFromSuperview()
        let errorLabel = UILabel()
        loadErrorLabel = errorLabel
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.text = "Settings couldn't be loaded.\n\(message)"
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
    }

    static func allowsNavigation(to url: URL, bundledURL: URL?) -> Bool {
        guard url.isFileURL, let bundledURL else { return false }
        // Compare the actual file, so #anchors work without admitting remote
        // URLs that happen to contain a fragment or unrelated local files.
        return url.standardizedFileURL.path == bundledURL.standardizedFileURL.path
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

        let bundledURL = Bundle.main.url(forResource: "settings", withExtension: "html")
        decisionHandler(Self.allowsNavigation(to: url, bundledURL: bundledURL) ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadErrorLabel?.removeFromSuperview()
        loadErrorLabel = nil
        updatePageActivity()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showLoadError(error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        showLoadError(error.localizedDescription)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // Recover the local page if WebKit is reclaimed under memory pressure.
        loadBundledSettings()
    }
}
