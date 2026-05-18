import UIKit

final class RecipeDetailVC: UIViewController {
    private let vm: RecipeDetailVM

    init(vm: RecipeDetailVM) {
        self.vm = vm
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .paper

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Spacing.s16
        stack.layoutMargins = .init(top: Spacing.s24, left: Spacing.s24, bottom: Spacing.s24, right: Spacing.s24)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])

        let title = UILabel()
        title.text = vm.recipe.title
        title.font = Typography.fraunces(32, weight: .bold)
        title.textColor = .ink
        title.numberOfLines = 0
        stack.addArrangedSubview(title)

        let time = UILabel()
        time.text = vm.recipe.estimatedTime.uppercased()
        time.font = Typography.dmSans(13, weight: .medium)
        time.textColor = .sage
        stack.addArrangedSubview(time)

        stack.addArrangedSubview(makeRule())
        stack.addArrangedSubview(makeSectionHeader("Ingredients"))
        for ing in vm.recipe.ingredients {
            stack.addArrangedSubview(makeBullet("• \(ing)"))
        }
        stack.addArrangedSubview(makeRule())
        stack.addArrangedSubview(makeSectionHeader("Steps"))
        for (idx, step) in vm.recipe.steps.enumerated() {
            stack.addArrangedSubview(makeBullet("\(idx + 1). \(step)"))
        }
    }

    private func makeSectionHeader(_ text: String) -> UIView {
        let l = UILabel()
        l.text = text
        l.font = Typography.fraunces(22, weight: .bold)
        l.textColor = .ink
        return l
    }

    private func makeBullet(_ text: String) -> UIView {
        let l = UILabel()
        l.text = text
        l.font = Typography.dmSans(16)
        l.textColor = .ink
        l.numberOfLines = 0
        return l
    }

    private func makeRule() -> UIView {
        let v = UIView()
        v.backgroundColor = .rule
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }
}
