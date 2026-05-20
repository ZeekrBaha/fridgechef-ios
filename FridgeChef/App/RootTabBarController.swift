import UIKit

final class RootTabBarController: UITabBarController {

    var deps: Dependencies?

    override func viewDidLoad() {
        super.viewDidLoad()
        let deps = self.deps ?? Dependencies.makeLive()

        let catalogVM = CatalogVM(
            client: deps.openAIClient,
            store: deps.recipeStore,
            dailyPicks: deps.dailyPicksService
        )
        let catalogVC = CatalogVC(vm: catalogVM)
        let catalogNav = UINavigationController(rootViewController: catalogVC)
        catalogNav.tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: "house"),
            tag: 0
        )

        let recipesVM = RecipesVM(store: deps.recipeStore)
        let recipesVC = RecipesVC(vm: recipesVM)
        let recipesNav = UINavigationController(rootViewController: recipesVC)
        recipesNav.tabBarItem = UITabBarItem(
            title: "Recipes",
            image: UIImage(systemName: "square.grid.2x2"),
            tag: 1
        )

        let settingsVM = SettingsVM(store: deps.recipeStore)
        let settingsVC = SettingsVC(vm: settingsVM)
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: "slider.horizontal.3"),
            tag: 2
        )

        viewControllers = [catalogNav, recipesNav, settingsNav]
    }
}
