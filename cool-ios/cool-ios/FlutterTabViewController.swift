import Flutter
import UIKit

/// A screen showing one Flutter engine; the HUD reports that engine's frames.
protocol FlutterRouteHosting: AnyObject {
    var route: String { get }
}

/// Hosts one persistent Flutter engine below UIKit's tab bar.
final class FlutterTabViewController: UIViewController, FlutterRouteHosting {
    let route: String
    private var flutterViewController: FlutterViewController?

    init(route: String, title: String, systemImageName: String) {
        self.route = route
        super.init(nibName: nil, bundle: nil)
        self.title = title
        tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: systemImageName),
            selectedImage: UIImage(systemName: systemImageName + ".fill")
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        embedFlutterIfNeeded()
    }

    private func embedFlutterIfNeeded() {
        guard flutterViewController == nil else { return }

        let engine = AppEngines.shared.engine(forRoute: route)
        let flutterVC = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        flutterVC.view.translatesAutoresizingMaskIntoConstraints = false
        flutterVC.view.backgroundColor = .clear

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
}
