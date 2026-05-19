import UIKit

final class RecipeBatchVC: UIViewController, UICollectionViewDelegate {

    private let vm: RecipeBatchVM
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, Recipe>!

    init(vm: RecipeBatchVM) {
        self.vm = vm
        super.init(nibName: nil, bundle: nil)
        title = "\(vm.recipes.count) recipes"
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .paper

        let layout = UICollectionViewCompositionalLayout { _, _ in
            let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(140)))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(140)), subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = Spacing.s12
            section.contentInsets = .init(top: Spacing.s32, leading: Spacing.s16, bottom: Spacing.s16, trailing: Spacing.s16)
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.register(RecipeBatchCardCell.self, forCellWithReuseIdentifier: RecipeBatchCardCell.reuseID)
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        let header = UILabel()
        header.text = vm.headerDateString
        header.font = Typography.dmSans(12, weight: .medium)
        header.textColor = .inkSoft
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Spacing.s8),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Spacing.s16),
        ])

        dataSource = UICollectionViewDiffableDataSource<Int, Recipe>(collectionView: collectionView) { cv, indexPath, recipe in
            let cell = cv.dequeueReusableCell(withReuseIdentifier: RecipeBatchCardCell.reuseID, for: indexPath) as! RecipeBatchCardCell
            cell.configure(with: recipe)
            return cell
        }
        var snap = NSDiffableDataSourceSnapshot<Int, Recipe>()
        snap.appendSections([0])
        snap.appendItems(vm.recipes)
        dataSource.apply(snap, animatingDifferences: false)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let recipe = vm.recipes[indexPath.item]
        guard let store = vm.store else { return }
        let detailVM = RecipeDetailVM(recipe: recipe, batchId: vm.batch.id, store: store)
        navigationController?.pushViewController(RecipeDetailVC(vm: detailVM), animated: true)
    }
}
