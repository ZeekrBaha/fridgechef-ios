import UIKit
import Combine

final class RecipesVC: UIViewController, UICollectionViewDelegate {

    private let vm: RecipesVM
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<String, RecipeBatch>!
    private let segmented = UISegmentedControl(items: ["All", "Favorites"])
    private var cancellables = Set<AnyCancellable>()

    init(vm: RecipesVM) {
        self.vm = vm
        super.init(nibName: nil, bundle: nil)
        title = "Recipes"
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .paper
        navigationController?.navigationBar.prefersLargeTitles = true

        let plus = UIBarButtonItem(barButtonSystemItem: .add, target: self,
                                   action: #selector(createTapped))
        plus.accessibilityIdentifier = "recipes.create.button"
        plus.accessibilityLabel = "Create new recipe"
        navigationItem.rightBarButtonItem = plus

        setupSegmented()
        setupCollectionView()
        bind()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { await vm.load() }
    }

    private func setupSegmented() {
        segmented.translatesAutoresizingMaskIntoConstraints = false
        segmented.selectedSegmentIndex = 0
        segmented.accessibilityIdentifier = "recipes.filter.segmented"
        segmented.accessibilityLabel = "Filter recipes"
        segmented.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        view.addSubview(segmented)
        NSLayoutConstraint.activate([
            segmented.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Spacing.s8),
            segmented.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Spacing.s16),
            segmented.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Spacing.s16),
        ])
    }

    private func setupCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.backgroundColor = .clear
        config.headerMode = .supplementary
        config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self,
                  let batch = self.batch(at: indexPath) else { return nil }
            let action = UIContextualAction(style: .destructive, title: "Delete") { _, _, done in
                self.confirmDeleteBatch(batch: batch, completion: done)
            }
            return UISwipeActionsConfiguration(actions: [action])
        }
        let layout = UICollectionViewCompositionalLayout.list(using: config)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.accessibilityIdentifier = "recipes.list"
        collectionView.delegate = self
        collectionView.register(RecipesBatchCell.self, forCellWithReuseIdentifier: RecipesBatchCell.reuseID)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: segmented.bottomAnchor, constant: Spacing.s8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        let headerReg = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            guard let self else { return }
            let identifiers = self.dataSource.snapshot().sectionIdentifiers
            guard identifiers.indices.contains(indexPath.section) else { return }
            let title = identifiers[indexPath.section]
            var content = header.defaultContentConfiguration()
            content.text = title
            content.textProperties.font = Typography.dmSans(11, weight: .medium)
            content.textProperties.color = .inkSoft
            content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 6, trailing: 0)
            header.contentConfiguration = content
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, ip, batch in
            let cell = cv.dequeueReusableCell(withReuseIdentifier: RecipesBatchCell.reuseID, for: ip) as! RecipesBatchCell
            cell.configure(with: batch)
            return cell
        }
        dataSource.supplementaryViewProvider = { cv, _, ip in
            cv.dequeueConfiguredReusableSupplementary(using: headerReg, for: ip)
        }
    }

    private func bind() {
        vm.$visibleGroups
            .sink { [weak self] in self?.render(groups: $0) }
            .store(in: &cancellables)
    }

    private func render(groups: [RecipesVM.Group]) {
        if groups.isEmpty {
            let emptySnap = NSDiffableDataSourceSnapshot<String, RecipeBatch>()
            dataSource.apply(emptySnap, animatingDifferences: false)
            var config = UIContentUnavailableConfiguration.empty()
            let iconCfg = UIImage.SymbolConfiguration(pointSize: 52, weight: .thin)
            config.image = UIImage(systemName: vm.filter == .favorites
                ? "heart.circle" : "fork.knife.circle", withConfiguration: iconCfg)
            config.imageProperties.tintColor = .inkSoft
            config.text = vm.filter == .favorites ? "No favorites yet" : "No recipes yet"
            config.textProperties.font = Typography.fraunces(20, weight: .bold)
            config.textProperties.color = .ink
            config.secondaryText = vm.filter == .favorites
                ? "Tap the heart on a recipe to favorite it."
                : "Tap + to add one, or generate from Home."
            config.secondaryTextProperties.font = Typography.dmSans(15)
            config.secondaryTextProperties.color = .inkSoft
            contentUnavailableConfiguration = config
            return
        }
        contentUnavailableConfiguration = nil
        var snap = NSDiffableDataSourceSnapshot<String, RecipeBatch>()
        for g in groups {
            snap.appendSections([g.title])
            snap.appendItems(g.items, toSection: g.title)
        }
        dataSource.apply(snap, animatingDifferences: true)
    }

    private func batch(at indexPath: IndexPath) -> RecipeBatch? {
        let snap = dataSource.snapshot()
        guard snap.sectionIdentifiers.indices.contains(indexPath.section) else { return nil }
        let sectionID = snap.sectionIdentifiers[indexPath.section]
        let items = snap.itemIdentifiers(inSection: sectionID)
        guard items.indices.contains(indexPath.item) else { return nil }
        return items[indexPath.item]
    }

    @objc private func segmentChanged() {
        vm.filter = segmented.selectedSegmentIndex == 0 ? .all : .favorites
    }

    @objc private func createTapped() {
        let createVM = CreateEditRecipeVM(mode: .new, store: vm.store)
        navigationController?.pushViewController(CreateEditRecipeVC(vm: createVM), animated: true)
    }

    private func confirmDeleteBatch(batch: RecipeBatch, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "Delete this batch?",
                                      message: "All \(batch.recipes.count) recipes will be removed.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(false) })
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            Task {
                await self?.vm.deleteBatch(id: batch.id)
                completion(true)
            }
        })
        present(alert, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let batch = batch(at: indexPath) else { return }
        // A recipe you created is a single-recipe batch — skip the batch screen
        // and open its detail directly, so Edit is one tap away.
        if batch.source == .user, batch.recipes.count == 1 {
            let detailVM = RecipeDetailVM(recipe: batch.recipes[0], batchId: batch.id, store: vm.store)
            navigationController?.pushViewController(RecipeDetailVC(vm: detailVM), animated: true)
        } else {
            let batchVM = RecipeBatchVM(batch: batch, store: vm.store)
            navigationController?.pushViewController(RecipeBatchVC(vm: batchVM), animated: true)
        }
    }
}
