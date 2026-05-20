import UIKit
import Combine

final class RecipeBatchVC: UIViewController, UICollectionViewDelegate {

    private let vm: RecipeBatchVM
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, Recipe>!
    private let headerLabel = UILabel()
    private var cancellables = Set<AnyCancellable>()

    init(vm: RecipeBatchVM) {
        self.vm = vm
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .paper

        let layout = UICollectionViewCompositionalLayout { [weak self] _, env in
            var config = UICollectionLayoutListConfiguration(appearance: .plain)
            config.backgroundColor = .clear
            config.showsSeparators = false
            config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                guard let self else { return nil }
                let recipe = self.vm.recipes[indexPath.item]
                let action = UIContextualAction(style: .destructive, title: "Delete") { _, _, done in
                    self.confirmDelete(recipe: recipe, completion: done)
                }
                return UISwipeActionsConfiguration(actions: [action])
            }
            let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: env)
            section.interGroupSpacing = Spacing.s12
            section.contentInsets = .init(top: Spacing.s32, leading: Spacing.s16,
                                          bottom: Spacing.s16, trailing: Spacing.s16)
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.register(RecipeBatchCardCell.self,
                                forCellWithReuseIdentifier: RecipeBatchCardCell.reuseID)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        headerLabel.font = Typography.dmSans(12, weight: .medium)
        headerLabel.textColor = .inkSoft
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Spacing.s8),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Spacing.s16),
        ])

        dataSource = UICollectionViewDiffableDataSource<Int, Recipe>(collectionView: collectionView) { cv, ip, recipe in
            let cell = cv.dequeueReusableCell(withReuseIdentifier: RecipeBatchCardCell.reuseID, for: ip) as! RecipeBatchCardCell
            cell.configure(with: recipe)
            return cell
        }

        bind()
    }

    private func bind() {
        vm.$batchState
            .sink { [weak self] state in self?.render(state: state) }
            .store(in: &cancellables)
    }

    private func render(state: RecipeBatchVM.BatchState) {
        switch state {
        case .loaded(let batch):
            title = "\(batch.recipes.count) recipes"
            headerLabel.text = vm.headerDateString
            var snap = NSDiffableDataSourceSnapshot<Int, Recipe>()
            snap.appendSections([0])
            snap.appendItems(batch.recipes)
            dataSource.apply(snap, animatingDifferences: true)
        case .gone:
            navigationController?.popViewController(animated: true)
        }
    }

    private func confirmDelete(recipe: Recipe, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "Delete this recipe?",
                                      message: recipe.title,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(false) })
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self else { completion(false); return }
            Task {
                await self.vm.deleteRecipe(id: recipe.id)
                completion(true)
            }
        })
        present(alert, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard vm.recipes.indices.contains(indexPath.item) else { return }
        let recipe = vm.recipes[indexPath.item]
        let detailVM = RecipeDetailVM(recipe: recipe, batchId: vm.initialBatchId, store: vm.store)
        navigationController?.pushViewController(RecipeDetailVC(vm: detailVM), animated: true)
    }
}
