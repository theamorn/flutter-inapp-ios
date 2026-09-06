import QuartzCore
import UIKit

/// A native, window-level overlay. Host cadence and process footprint never come from Flutter.
final class PerformanceHUDView: UIView {
    static let shared = PerformanceHUDView()

    private struct FlutterSample {
        let uiMillis: Double
        let rasterMillis: Double
        let fps: Double
        let receivedAt: CFTimeInterval
    }

    private struct EngineSpawn {
        let deltaBytes: Int64
        let durationMillis: Double
    }

    private let headerStack = UIStackView()
    private let titleLabel = UILabel()
    private let toggleButton = UIButton(type: .system)
    private let hostLabel = UILabel()
    private let flutterLabel = UILabel()
    private let enginesLabel = UILabel()

    private var isMinimized = false
    private var displayLink: CADisplayLink!
    private var sampleStartTimestamp: CFTimeInterval?
    private var frameCount = 0
    private var hostFPS = 0.0
    private var activeFlutterRoute: String?
    private var flutterSamples: [String: FlutterSample] = [:]
    private var engineSpawns: [String: EngineSpawn] = [:]

    private override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        configureDisplayLink()
        refreshLabels()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func attach(to window: UIWindow) {
        if superview !== window {
            removeFromSuperview()
            translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(self)
            NSLayoutConstraint.activate([
                topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 8),
                trailingAnchor.constraint(equalTo: window.safeAreaLayoutGuide.trailingAnchor, constant: -8),
                leadingAnchor.constraint(greaterThanOrEqualTo: window.safeAreaLayoutGuide.leadingAnchor, constant: 8),
                widthAnchor.constraint(lessThanOrEqualToConstant: 520),
            ])
        }
        window.bringSubviewToFront(self)
    }

    func setActiveFlutterRoute(_ route: String?) {
        if route != activeFlutterRoute, let route {
            flutterSamples.removeValue(forKey: route)
        }
        activeFlutterRoute = route
        refreshLabels()
    }

    func recordFlutterSample(
        route: String,
        uiMillis: Double,
        rasterMillis: Double,
        fps: Double
    ) {
        flutterSamples[route] = FlutterSample(
            uiMillis: uiMillis,
            rasterMillis: rasterMillis,
            fps: fps,
            receivedAt: CACurrentMediaTime()
        )
        refreshLabels()
    }

    func recordEngineSpawn(route: String, deltaBytes: Int64, durationMillis: Double) {
        engineSpawns[route] = EngineSpawn(
            deltaBytes: deltaBytes,
            durationMillis: durationMillis
        )
        refreshLabels()
    }

    private func configureView() {
        isUserInteractionEnabled = true
        backgroundColor = UIColor.black.withAlphaComponent(0.84)
        layer.cornerRadius = 10
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.75).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)

        titleLabel.text = "LIVE PERFORMANCE"
        titleLabel.textColor = .systemGreen
        titleLabel.font = .monospacedSystemFont(ofSize: 12, weight: .bold)

        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
        toggleButton.configuration = config
        toggleButton.setTitle("Hide ▴", for: .normal)
        toggleButton.setTitleColor(.systemGreen, for: .normal)
        toggleButton.titleLabel?.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        toggleButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.18)
        toggleButton.layer.cornerRadius = 6
        toggleButton.layer.borderWidth = 0.5
        toggleButton.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.5).cgColor
        toggleButton.addTarget(self, action: #selector(toggleMinimized), for: .touchUpInside)

        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.distribution = .equalSpacing
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(toggleButton)

        // Keep all three spawn measurements readable on a phone/projector.
        enginesLabel.numberOfLines = 0
        [hostLabel, flutterLabel, enginesLabel].forEach {
            $0.textColor = .white
            $0.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
            $0.adjustsFontSizeToFitWidth = true
            $0.minimumScaleFactor = 0.75
        }

        let stack = UIStackView(arrangedSubviews: [
            headerStack,
            hostLabel,
            flutterLabel,
            enginesLabel,
        ])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(hudTapped))
        addGestureRecognizer(tapGesture)
    }

    private func configureDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        displayLink.preferredFrameRateRange = CAFrameRateRange(
            minimum: 30,
            maximum: Float(UIScreen.main.maximumFramesPerSecond),
            preferred: Float(UIScreen.main.maximumFramesPerSecond)
        )
        displayLink.add(to: .main, forMode: .common)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetFrameWindow(_:)),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetFrameWindow(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func displayLinkDidFire(_ link: CADisplayLink) {
        guard let start = sampleStartTimestamp else {
            sampleStartTimestamp = link.timestamp
            frameCount = 0
            return
        }

        frameCount += 1
        let elapsed = link.timestamp - start
        guard elapsed >= 1 else { return }

        hostFPS = Double(frameCount) / elapsed
        sampleStartTimestamp = link.timestamp
        frameCount = 0
        refreshLabels()
    }

    @objc private func resetFrameWindow(_ notification: Notification) {
        sampleStartTimestamp = nil
        frameCount = 0
        hostFPS = 0
        flutterSamples.removeAll()
        displayLink.isPaused = notification.name == UIApplication.willResignActiveNotification
        refreshLabels()
    }

    @objc private func toggleMinimized() {
        isMinimized.toggle()
        updateDisplayMode(animated: true)
    }

    @objc private func hudTapped() {
        if isMinimized {
            toggleMinimized()
        }
    }

    private func updateDisplayMode(animated: Bool) {
        let updates = {
            self.layer.cornerRadius = self.isMinimized ? 14 : 10
            self.hostLabel.isHidden = self.isMinimized
            self.flutterLabel.isHidden = self.isMinimized
            self.enginesLabel.isHidden = self.isMinimized
            self.toggleButton.isHidden = self.isMinimized
            self.refreshLabels()
            self.superview?.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut], animations: updates)
        } else {
            updates()
        }
    }

    private func refreshLabels() {
        if isMinimized {
            titleLabel.text = String(format: "● %.0f FPS ▾", hostFPS)
            titleLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
            titleLabel.textColor = .white
            return
        }

        titleLabel.text = "LIVE PERFORMANCE"
        titleLabel.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        titleLabel.textColor = .systemGreen

        let memoryMB = Double(MemoryProbe.footprintBytes()) / 1_048_576
        hostLabel.text = String(format: "HOST     %5.1f fps   %6.1f MiB footprint", hostFPS, memoryMB)

        if let route = activeFlutterRoute, let sample = flutterSamples[route],
           CACurrentMediaTime() - sample.receivedAt <= 2 {
            flutterLabel.text = String(
                format: "FLUTTER  %@  UI %.1f ms  raster %.1f ms  %.0f fps",
                route,
                sample.uiMillis,
                sample.rasterMillis,
                sample.fps
            )
        } else if let route = activeFlutterRoute {
            flutterLabel.text = "FLUTTER  \(route)  no recent frames"
        } else {
            flutterLabel.text = "FLUTTER  —  no active Flutter engine"
        }

        let routeOrder = [AppEngines.gameRoute, AppEngines.glassRoute, AppEngines.sceneRoute]
        let summaries = routeOrder.compactMap { route -> String? in
            guard let spawn = engineSpawns[route] else { return nil }
            let deltaMB = Double(spawn.deltaBytes) / 1_048_576
            return String(format: "%@ %+.1f MiB/%.0f ms create", route, deltaMB, spawn.durationMillis)
        }
        enginesLabel.text = summaries.isEmpty
            ? "ENGINES  lazy — none spawned"
            : "ENGINES  " + summaries.joined(separator: "\n         ")
    }
}
