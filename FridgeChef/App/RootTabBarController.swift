import UIKit

final class RootTabBarController: UITabBarController {

    var deps: Dependencies?

    override func viewDidLoad() {
        super.viewDidLoad()
        let deps = self.deps ?? Dependencies.makeLive()

        let homeVM = HomeVM(client: deps.openAIClient, store: deps.recipeStore)
        let homeVC = HomeVC(vm: homeVM)
        let homeNav = UINavigationController(rootViewController: homeVC)
        homeNav.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)

        let recipesVM = RecipesVM(store: deps.recipeStore)
        let recipesVC = RecipesVC(vm: recipesVM)
        let recipesNav = UINavigationController(rootViewController: recipesVC)
        recipesNav.tabBarItem = UITabBarItem(title: "Recipes", image: UIImage(systemName: "book"), tag: 1)

        let settingsVM = SettingsVM(store: deps.recipeStore)
        let settingsVC = SettingsVC(vm: settingsVM)
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape"), tag: 2)

        viewControllers = [homeNav, recipesNav, settingsNav]
    }
}

@MainActor
struct Dependencies {
    let openAIClient: OpenAIClientProtocol
    let recipeStore: RecipeStoreProtocol

    static func makeLive() -> Dependencies {
        let stack = CoreDataStack()
        let store = RecipeStore(stack: stack)
        let apiKey = (try? APIKeyProvider.get()) ?? ""
        let client = OpenAIClient(apiKey: apiKey, session: .shared)
        return Dependencies(openAIClient: client, recipeStore: store)
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
        view.backgroundColor = .paper
        let label = UILabel()
        label.text = title
        label.font = Typography.fraunces(34, weight: .bold)
        label.textColor = .ink
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
