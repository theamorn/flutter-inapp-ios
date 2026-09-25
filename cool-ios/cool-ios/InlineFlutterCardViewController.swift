import Flutter
import UIKit

/// Hosts the `/promo` engine as a fixed-height tile inside a native page.
///
/// Unlike `FlutterTabViewController`, Flutter is not the screen here: the page
/// around it owns scrolling, visibility, and the price. This controller owns
/// the promo channel; its contract is in `docs/hybrid-demo/ARCHITECTURE.md`.
final class InlineFlutterCardViewController: UIViewController {
    static let height: CGFloat = 340

    /// Matches `HoloCardGame.backdropColor`, so there is no flash before the
    /// first Flutter frame and no seam at the tile's edge.
    static let backdropColor = UIColor(red: 12 / 255, green: 10 / 255, blue: 28 / 255, alpha: 1)

    /// Extra margin around the badge that still counts as grabbing it; the
    /// reported bounds can be a frame or two behind a moving badge.
    private static let touchSlop: CGFloat = 16

    /// Called when Flutter reports the promo was claimed. The page owns the price.
    var onClaim: ((String) -> Void)?

    /// The tile's state as the page sees it, for Flutter's `ready` pull.
    var hostState: (() -> (visible: Bool, progress: Double))?

    /// The badge's last reported bounds, in this view's points.
    private var badgeBounds: CGRect?
    private var flutterViewController: FlutterViewController?
    private var channel: FlutterMethodChannel?
    private var sentVisible: Bool?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Self.backdropColor
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.accessibilityLabel = "Holo member badge, 20 percent off"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        embedFlutterIfNeeded()
    }

    /// Spawns the engine on the Shop tab's first appearance, never when the
    /// tile scrolls into view: engine creation is synchronous and would drop
    /// frames mid-scroll.
    private func embedFlutterIfNeeded() {
        guard flutterViewController == nil else { return }

        let engine = AppEngines.shared.engine(forRoute: AppEngines.promoRoute)
        attachChannel(to: engine)
        let flutterVC = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        flutterVC.view.translatesAutoresizingMaskIntoConstraints = false
        flutterVC.view.backgroundColor = Self.backdropColor

        addChild(flutterVC)
        view.addSubview(flutterVC.view)
        NSLayoutConstraint.activate([
            flutterVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            flutterVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            flutterVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            flutterVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        flutterVC.didMove(toParent: self)
        flutterViewController = flutterVC
    }

    private func attachChannel(to engine: FlutterEngine) {
        let channel = FlutterMethodChannel(
            name: AppEngines.promoChannelName,
            binaryMessenger: engine.binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(nil)
                return
            }
            let arguments = call.arguments as? [String: Any]
            switch call.method {
            case "ready":
                let state = self.hostState?() ?? (visible: true, progress: 0)
                self.sentVisible = state.visible
                result(["visible": state.visible, "progress": state.progress])
            case "badgeBounds":
                guard let x = Self.double(arguments?["x"]),
                      let y = Self.double(arguments?["y"]),
                      let width = Self.double(arguments?["w"]),
                      let height = Self.double(arguments?["h"]) else {
                    result(FlutterError(
                        code: "invalid_bounds",
                        message: "Expected x, y, w, and h numbers",
                        details: nil
                    ))
                    return
                }
                self.badgeBounds = CGRect(x: x, y: y, width: width, height: height)
                result(nil)
            case "claimPromo":
                self.onClaim?(arguments?["code"] as? String ?? "")
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        self.channel = channel
    }

    /// Tells Flutter whether the tile can be seen. Sent only on change, unless
    /// [force]d after something that may have desynchronized the two sides.
    func sendVisibility(_ visible: Bool, force: Bool = false) {
        guard force || visible != sentVisible else { return }
        sentVisible = visible
        channel?.invokeMethod("visibility", arguments: ["visible": visible])
    }

    func sendScroll(progress: Double, velocity: Double) {
        channel?.invokeMethod("scroll", arguments: ["progress": progress, "velocity": velocity])
    }

    /// Whether a touch that started at `point`, in this view's coordinates,
    /// belongs to the badge rather than to the page's scroll.
    func ownsTouch(startingAt point: CGPoint) -> Bool {
        guard let badgeBounds else { return false }
        return badgeBounds.insetBy(dx: -Self.touchSlop, dy: -Self.touchSlop).contains(point)
    }

    private static func double(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }
}
