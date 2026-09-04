import UIKit

final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        configureTabBarAppearance()

        viewControllers = [
            nativeTab(
                root: HomeViewController(),
                title: "Home",
                systemImageName: "house"
            ),
            nativeTab(
                root: SettingsWebViewController(),
                title: "Web",
                systemImageName: "globe"
            ),
            FlutterTabViewController(
                route: AppEngines.gameRoute,
                title: "Game",
                systemImageName: "gamecontroller"
            ),
            FlutterTabViewController(
                route: AppEngines.glassRoute,
                title: "Glass",
                systemImageName: "drop"
            ),
            FlutterTabViewController(
                route: AppEngines.sceneRoute,
                title: "Island",
                systemImageName: "mountain.2"
            ),
        ]
        selectedIndex = 0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let window = view.window else { return }
        PerformanceHUDView.shared.attach(to: window)
        updateHUDRoute(for: selectedViewController)
    }

    private func nativeTab(
        root: UIViewController,
        title: String,
        systemImageName: String
    ) -> UIViewController {
        let navigation = UINavigationController(rootViewController: root)
        navigation.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: systemImageName),
            selectedImage: UIImage(systemName: systemImageName + ".fill")
        )
        return navigation
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = .systemPurple
    }

    private func updateHUDRoute(for viewController: UIViewController?) {
        let route = (viewController as? FlutterTabViewController)?.route
        PerformanceHUDView.shared.setActiveFlutterRoute(route)
    }
}

extension MainTabBarController: UITabBarControllerDelegate {
    func tabBarController(
        _ tabBarController: UITabBarController,
        didSelect viewController: UIViewController
    ) {
        updateHUDRoute(for: viewController)
        if let window = view.window {
            PerformanceHUDView.shared.attach(to: window)
        }
    }
}
