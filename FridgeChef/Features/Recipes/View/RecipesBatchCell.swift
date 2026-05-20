import UIKit

final class RecipesBatchCell: UICollectionViewListCell {
    static let reuseID = "RecipesBatchCell"

    private let accentBar  = UIView()
    private let titleLabel = UILabel()
    private let metaLabel  = UILabel()
    private let tagsRow    = UIStackView()
    private let heartIcon  = UIImageView()

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        accentBar.layer.cornerRadius = 1.5
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(accentBar)

        titleLabel.font = Typography.fraunces(17, weight: .bold)
        titleLabel.textColor = .ink
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        metaLabel.font = Typography.dmSans(12)
        metaLabel.textColor = .inkSoft
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(metaLabel)

        tagsRow.axis = .horizontal
        tagsRow.spacing = 6
        tagsRow.clipsToBounds = true
        tagsRow.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tagsRow)

        let cfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        heartIcon.image = UIImage(systemName: "heart.fill", withConfiguration: cfg)
        heartIcon.tintColor = .terracotta
        heartIcon.contentMode = .scaleAspectFit
        heartIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(heartIcon)

        NSLayoutConstraint.activate([
            accentBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            accentBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            accentBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            titleLabel.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: heartIcon.leadingAnchor, constant: -8),

            heartIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            heartIcon.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            heartIcon.widthAnchor.constraint(equalToConstant: 14),
            heartIcon.heightAnchor.constraint(equalToConstant: 14),

            metaLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            metaLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            tagsRow.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            tagsRow.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 10),
            tagsRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            tagsRow.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    func configure(with batch: RecipeBatch) {
        // A recipe you created yourself is a single-recipe batch: show its real
        // name as the title and its ingredients as chips. AI batches show the
        // ingredient query as the title and the generated recipe names as chips.
        let isSingleUserRecipe = batch.source == .user && batch.recipes.count == 1

        if isSingleUserRecipe {
            titleLabel.text = batch.recipes[0].title
        } else if batch.inputIngredients.isEmpty {
            titleLabel.text = batch.source == .user ? "Your recipes" : "Generated recipes"
        } else {
            titleLabel.text = batch.inputIngredients.joined(separator: ", ")
        }

        accentBar.backgroundColor = batch.source == .user ? .terracotta : .sage

        let count = batch.recipes.count
        metaLabel.text = "\(count) \(count == 1 ? "recipe" : "recipes") · \(Self.timeFmt.string(from: batch.createdAt))"

        heartIcon.isHidden = !batch.recipes.contains(where: \.isFavorite)

        let chipSource = isSingleUserRecipe ? batch.recipes[0].ingredients : batch.recipes.map(\.title)
        tagsRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for text in chipSource.prefix(3) {
            tagsRow.addArrangedSubview(makeChip(text))
        }
        if chipSource.count > 3 {
            tagsRow.addArrangedSubview(makeChip("+\(chipSource.count - 3)"))
        }

        var bg = UIBackgroundConfiguration.listGroupedCell()
        bg.backgroundColor = .paper2
        backgroundConfiguration = bg
    }

    private func makeChip(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = Typography.dmSans(11, weight: .medium)
        label.textColor = .inkSoft
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail

        let chip = UIView()
        chip.backgroundColor = UIColor.ink.withAlphaComponent(0.07)
        chip.layer.cornerRadius = 8

        label.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: 7),
            label.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -7),
            label.topAnchor.constraint(equalTo: chip.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: chip.bottomAnchor, constant: -3),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 80),
        ])
        return chip
    }
}
