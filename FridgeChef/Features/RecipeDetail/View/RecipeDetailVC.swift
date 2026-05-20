import UIKit
import Combine

final class RecipeDetailVC: UIViewController {

    private let vm: RecipeDetailVM
    private let contentStack = UIStackView()
    private var cancellables = Set<AnyCancellable>()

    private lazy var heartButton: UIBarButtonItem = {
        let b = UIBarButtonItem(image: UIImage(systemName: "heart"),
                                style: .plain, target: self, action: #selector(heartTapped))
        b.tintColor = .terracotta
        b.accessibilityIdentifier = "detail.favorite.button"
        return b
    }()

    private lazy var editButton: UIBarButtonItem = {
        let b = UIBarButtonItem(title: "Edit", style: .plain,
                                target: self, action: #selector(editTapped))
        b.accessibilityIdentifier = "detail.edit.button"
        return b
    }()

    init(vm: RecipeDetailVM) {
        self.vm = vm
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true   // hide the tab bar so the bottom toolbar can host the favorite
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .paper
        navigationItem.rightBarButtonItem = editButton
        toolbarItems = [.flexibleSpace(), heartButton, .flexibleSpace()]
        setupLayout()
        bind()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setToolbarHidden(true, animated: animated)
    }

    private func setupLayout() {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        contentStack.axis = .vertical
        contentStack.spacing = Spacing.s16
        contentStack.layoutMargins = .init(top: Spacing.s24, left: Spacing.s24,
                                           bottom: Spacing.s24, right: Spacing.s24)
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scroll.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])
    }

    private func bind() {
        vm.$recipe
            .sink { [weak self] in self?.rebuildContent(with: $0) }
            .store(in: &cancellables)

        vm.$isFavorite
            .sink { [weak self] fav in
                self?.heartButton.image = UIImage(systemName: fav ? "heart.fill" : "heart")
                self?.heartButton.accessibilityLabel = fav ? "Unfavorite" : "Favorite"
            }
            .store(in: &cancellables)

        vm.$lastError
            .compactMap { $0 }
            .sink { [weak self] msg in
                let alert = UIAlertController(title: "Couldn't save favorite",
                                              message: msg, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    self?.vm.clearError()
                })
                self?.present(alert, animated: true)
            }
            .store(in: &cancellables)
    }

    private func rebuildContent(with recipe: Recipe) {
        for v in contentStack.arrangedSubviews {
            contentStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        let titleLabel = UILabel()
        titleLabel.text = recipe.title
        titleLabel.font = Typography.fraunces(32, weight: .bold)
        titleLabel.textColor = .ink
        titleLabel.numberOfLines = 0
        contentStack.addArrangedSubview(titleLabel)

        let time = UILabel()
        time.text = recipe.estimatedTime.uppercased()
        time.font = Typography.dmSans(13, weight: .medium)
        time.textColor = .sage
        contentStack.addArrangedSubview(time)

        contentStack.addArrangedSubview(makeRule())
        contentStack.addArrangedSubview(makeSectionHeader("Ingredients"))
        for ing in recipe.ingredients {
            contentStack.addArrangedSubview(makeBullet("• \(ing)"))
        }
        contentStack.addArrangedSubview(makeRule())
        contentStack.addArrangedSubview(makeSectionHeader("Steps"))
        for (idx, step) in recipe.steps.enumerated() {
            contentStack.addArrangedSubview(makeBullet("\(idx + 1). \(step)"))
        }
    }

    @objc private func heartTapped() {
        Task { await vm.toggleFavorite() }
    }

    @objc private func editTapped() {
        let editVM = CreateEditRecipeVM(
            mode: .edit(existing: vm.recipe, batchId: vm.batchId),
            store: vm.makeStoreReference()
        )
        navigationController?.pushViewController(CreateEditRecipeVC(vm: editVM), animated: true)
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
