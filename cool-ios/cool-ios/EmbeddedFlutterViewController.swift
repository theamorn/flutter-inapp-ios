import Flutter
import UIKit

/// Hosts one Flutter route as a view inside a native page: the Shop page's 3D
/// header (`/product`) and its Review Details tab (`/reviews`).
///
/// The smallest host contract there is: the page says whether the view can
/// be seen (`visibility`), and Dart pulls that state when it starts (`ready`).
/// Flutter owns every touch that starts inside the view. The promo tile has
/// its own controller because its badge owns only part of its tile.
final class EmbeddedFlutterViewController: UIViewController, FlutterTouchOwner {
    let route: String
    private let channelName: String
    private let backdropColor: UIColor
    private let cornerRadius: CGFloat

    private var flutterViewController: FlutterViewController?
    private var channel: FlutterMethodChannel?
    private var sentVisible: Bool?

    /// What the page wants Flutter to know, answered on `ready`.
    private(set) var visible = false

    init(route: String, channelName: String, backdropColor: UIColor, cornerRadius: CGFloat = 0) {
        self.route = route
        self.channelName = channelName
        self.backdropColor = backdropColor
        self.cornerRadius = cornerRadius
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = backdropColor
        if cornerRadius > 0 {
            view.layer.cornerRadius = cornerRadius
            view.layer.cornerCurve = .continuous
            view.clipsToBounds = true
        }
    }

    /// Spawns the engine and attaches the view. The page calls this on its
    /// first appearance, never on a tap: engine creation is synchronous and
    /// would drop frames in the middle of an interaction.
    func embedIfNeeded() {
        guard flutterViewController == nil else { return }
        loadViewIfNeeded()

        let engine = AppEngines.shared.engine(forRoute: route)
        attachChannel(to: engine)
        let flutterVC = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        flutterVC.view.translatesAutoresizingMaskIntoConstraints = false
        flutterVC.view.backgroundColor = backdropColor

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
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: engine.binaryMessenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(nil)
                return
            }
            switch call.method {
            case "ready":
                self.sentVisible = self.visible
                result(["visible": self.visible])
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        self.channel = channel
    }

    /// Tells Flutter whether the view can be seen. Sent only on change, unless
    /// [force]d after something that may have desynchronized the two sides.
    func sendVisibility(_ visible: Bool, force: Bool = false) {
        self.visible = visible
        guard force || visible != sentVisible else { return }
        sentVisible = visible
        channel?.invokeMethod("visibility", arguments: ["visible": visible])
    }

    /// Every drag that starts here is Flutter's: orbiting the model, or
    /// scrolling the review list.
    func ownsTouch(startingAt point: CGPoint) -> Bool {
        true
    }
}
