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

