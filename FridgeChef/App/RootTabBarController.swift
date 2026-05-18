import UIKit

final class RootTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let homeNav = UINavigationController(rootViewController: PlaceholderVC(title: "Home"))
        homeNav.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)

        let recipesNav = UINavigationController(rootViewController: PlaceholderVC(title: "Recipes"))
        recipesNav.tabBarItem = UITabBarItem(title: "Recipes", image: UIImage(systemName: "book"), tag: 1)

        let settingsNav = UINavigationController(rootViewController: PlaceholderVC(title: "Settings"))
        settingsNav.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape"), tag: 2)

        viewControllers = [homeNav, recipesNav, settingsNav]
    }
}

private final class PlaceholderVC: UIViewController {
    init(title: String) {
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .largeTitle)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
