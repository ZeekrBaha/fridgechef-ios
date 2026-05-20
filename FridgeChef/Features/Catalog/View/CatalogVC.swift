import UIKit
import Combine
import PhotosUI

final class CatalogVC: UIViewController {

    // MARK: - Cards model

    private enum Card: Hashable {
        case meal(MealType)
        case fridge
    }

    // MARK: - VM

    private let vm: CatalogVM
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let inputField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "How to cook…"
        tf.font = Typography.body
        tf.borderStyle = .roundedRect
        tf.returnKeyType = .go
        tf.accessibilityIdentifier = "catalog.input"
        return tf
    }()

    private let helperLabel: UILabel = {
        let l = UILabel()
        l.text = "Enter the name of any dish"
        l.font = Typography.caption
        l.textColor = .inkSoft
        return l
    }()

    private let sectionHeader: UILabel = {
        let l = UILabel()
        l.text = "Recipe Catalog"
        l.font = Typography.largeTitle
        l.textColor = .ink
        l.accessibilityIdentifier = "catalog.header"
        return l
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let item = NSCollectionLayoutItem(layoutSize: .init(
                widthDimension: .fractionalWidth(0.5),
                heightDimension: .fractionalHeight(1.0)))
            item.contentInsets = .init(top: 6, leading: 6, bottom: 6, trailing: 6)
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                                  heightDimension: .absolute(140)),
                subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = .init(top: 6, leading: 10, bottom: 6, trailing: 10)
            return section
        }
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.isScrollEnabled = false
        cv.register(CategoryCardCell.self, forCellWithReuseIdentifier: CategoryCardCell.reuseID)
        return cv
    }()

    private var dataSource: UICollectionViewDiffableDataSource<Int, Card>!

    private let magicButton: UIButton = {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        b.setImage(UIImage(systemName: "sparkles", withConfiguration: cfg), for: .normal)
        b.tintColor = .white
        b.backgroundColor = .terracotta
        b.layer.cornerRadius = 28
        b.translatesAutoresizingMaskIntoConstraints = false
        b.accessibilityIdentifier = "catalog.magic"
        b.accessibilityLabel = "Surprise me"
        b.accessibilityHint = "Generate three random recipes"
        NSLayoutConstraint.activate([
            b.widthAnchor.constraint(equalToConstant: 56),
            b.heightAnchor.constraint(equalToConstant: 56)
        ])
        return b
    }()

    private let magicHelper: UILabel = {
        let l = UILabel()
        l.text = "Can't decide what to cook?\nJust press the button"
        l.numberOfLines = 2
        l.textAlignment = .center
        l.font = Typography.caption
        l.textColor = .inkSoft
        return l
    }()

    // Loading overlay (inlined — pattern lifted from HomeVC v1).
    private var loadingOverlay: UIView?

    // MARK: - Init

    init(vm: CatalogVM) {
        self.vm = vm
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .paper
        title = "Home"

        setUpLayout()
        configureDataSource()
        bindVM()
        wireActions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        vm.refreshDailyPicksIfStale()
    }

    // MARK: - Layout

    private func setUpLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        contentStack.axis = .vertical
        contentStack.spacing = Spacing.s24
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let inputBlock = UIStackView(arrangedSubviews: [inputField, helperLabel])
        inputBlock.axis = .vertical
        inputBlock.spacing = Spacing.s4

        let magicBlock = UIStackView(arrangedSubviews: [magicButton, magicHelper])
        magicBlock.axis = .vertical
        magicBlock.alignment = .center
        magicBlock.spacing = Spacing.s8

        [inputBlock, sectionHeader, collectionView, magicBlock].forEach {
            contentStack.addArrangedSubview($0)
        }
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: Spacing.s24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -Spacing.s24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: Spacing.s24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -Spacing.s24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -Spacing.s24 * 2),

            collectionView.heightAnchor.constraint(equalToConstant: 292)
        ])
    }

    // MARK: - Diffable

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Int, Card>(
            collectionView: collectionView
        ) { [weak self] cv, indexPath, card in
            let cell = cv.dequeueReusableCell(withReuseIdentifier: CategoryCardCell.reuseID, for: indexPath) as! CategoryCardCell
            switch card {
            case .meal(let meal):
                let pick = self?.vm.dailyPicks?.title(for: meal)
                cell.configure(title: "\(meal.displayName)\nideas", pick: pick)
                cell.accessibilityIdentifier = "catalog.card.\(meal.rawValue)"
                cell.accessibilityLabel = "\(meal.displayName) ideas. " +
                    (pick.map { "Today: \($0)." } ?? "Loading.")
            case .fridge:
                cell.configureFridge()
                cell.accessibilityIdentifier = "catalog.card.fridge"
                cell.accessibilityLabel = "From my fridge. Snap a photo."
            }
            return cell
        }
        collectionView.delegate = self
        applySnapshot()
    }

    private func applySnapshot() {
        var snap = NSDiffableDataSourceSnapshot<Int, Card>()
        snap.appendSections([0])
        snap.appendItems([.meal(.breakfast), .meal(.lunch), .meal(.dinner), .fridge])
        dataSource.apply(snap, animatingDifferences: false)
    }

    // MARK: - VM bindings

    private func bindVM() {
        vm.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.render(state) }
            .store(in: &cancellables)

        vm.$dailyPicks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applySnapshot()
            }
            .store(in: &cancellables)

        vm.$presentPhotoPicker
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                if show { self?.presentPhotoPicker() }
            }
            .store(in: &cancellables)
    }

    private func render(_ state: CatalogVM.State) {
        switch state {
        case .idle:
            hideOverlay()
        case .loading:
            showOverlay()
        case .loaded(let batch):
            hideOverlay()
            let detail = RecipeBatchVC(vm: RecipeBatchVM(batch: batch, store: vm.store))
            navigationController?.pushViewController(detail, animated: true)
        case .error(let msg):
            hideOverlay()
            let alert = UIAlertController(title: "Couldn't generate", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    private func showOverlay() {
        guard loadingOverlay == nil else { return }
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.ink.withAlphaComponent(0.6)

        let panConfig = UIImage.SymbolConfiguration(pointSize: 56, weight: .regular)
        let panImage = UIImage(systemName: "frying.pan.fill", withConfiguration: panConfig)
            ?? UIImage(systemName: "fork.knife", withConfiguration: panConfig)
        let spinner = UIImageView(image: panImage)
        spinner.tintColor = .paper
        spinner.contentMode = .scaleAspectFit
        let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
        rotate.toValue = 2 * Double.pi
        rotate.duration = 1.6
        rotate.repeatCount = .infinity
        spinner.layer.add(rotate, forKey: "rotate")
        let label = UILabel()
        label.text = "Cooking up ideas…"
        label.textColor = .paper
        label.font = Typography.body
        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Spacing.s8
        stack.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: v.centerYAnchor)
        ])

        view.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: view.topAnchor),
            v.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            v.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        loadingOverlay = v
    }

    private func hideOverlay() {
        loadingOverlay?.removeFromSuperview()
        loadingOverlay = nil
    }

    // MARK: - Actions

    private func wireActions() {
        inputField.delegate = self
        magicButton.addTarget(self, action: #selector(didTapMagic), for: .touchUpInside)
    }

    @objc private func didTapMagic() { vm.generateRandom() }

    private func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension CatalogVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if let text = textField.text { vm.generateForDish(text) }
        textField.text = ""
        return true
    }
}

// MARK: - UICollectionViewDelegate

extension CatalogVC: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let card = dataSource.itemIdentifier(for: indexPath) else { return }
        collectionView.deselectItem(at: indexPath, animated: true)
        switch card {
        case .meal(let meal): vm.generateForMeal(meal)
        case .fridge:         vm.openPhotoPicker()
        }
    }
}

// MARK: - PHPickerViewControllerDelegate

extension CatalogVC: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        vm.didDismissPhotoPicker()
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let image = obj as? UIImage,
                  let jpeg = image.jpegData(compressionQuality: 0.7) else { return }
            Task { @MainActor in self?.vm.generateFromImage(jpeg) }
        }
    }
}
