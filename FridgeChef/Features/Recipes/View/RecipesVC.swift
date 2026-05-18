import UIKit
import Combine

final class RecipesVC: UIViewController, UICollectionViewDelegate {

    private let vm: RecipesVM
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<String, RecipeBatch>!
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
        setupCollectionView()
        bind()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { await vm.load() }
    }

    private func setupCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.backgroundColor = .clear
        config.headerMode = .supplementary
        let layout = UICollectionViewCompositionalLayout.list(using: config)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.register(RecipesBatchCell.self, forCellWithReuseIdentifier: RecipesBatchCell.reuseID)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        let headerReg = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            guard let title = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section] else { return }
            var content = header.defaultContentConfiguration()
            content.text = title
            content.textProperties.font = Typography.dmSans(12, weight: .medium)
            content.textProperties.color = .inkSoft
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
        vm.$groups
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.render(groups: $0) }
            .store(in: &cancellables)
    }

    private func render(groups: [RecipesVM.Group]) {
        if groups.isEmpty {
            var config = UIContentUnavailableConfiguration.empty()
            config.text = "No recipes yet"
            config.secondaryText = "Head to Home to generate some."
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

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let title = dataSource.snapshot().sectionIdentifiers[indexPath.section]
        guard let group = vm.groups.first(where: { $0.title == title }) else { return }
        let batch = group.items[indexPath.item]
        navigationController?.pushViewController(RecipeBatchVC(vm: RecipeBatchVM(batch: batch)), animated: true)
    }
}
