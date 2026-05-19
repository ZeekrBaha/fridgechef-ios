import UIKit

final class RecipeBatchCardCell: UICollectionViewCell {
    static let reuseID = "RecipeBatchCardCell"

    private let titleLabel = UILabel()
    private let descLabel = UILabel()
    private let badges = UILabel()
    private let timeLabel = UILabel()
    private let heart = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .paper2
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.rule.cgColor

        titleLabel.font = Typography.fraunces(20, weight: .bold)
        titleLabel.textColor = .ink
        descLabel.font = Typography.dmSans(14)
        descLabel.textColor = .inkSoft
        descLabel.numberOfLines = 2
        badges.font = Typography.dmSans(12, weight: .medium)
        badges.textColor = .terracotta
        badges.numberOfLines = 1
        timeLabel.font = Typography.dmSans(12, weight: .medium)
        timeLabel.textColor = .sage

        let stack = UIStackView(arrangedSubviews: [titleLabel, descLabel, badges, timeLabel])
        stack.axis = .vertical
        stack.spacing = Spacing.s4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.s16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.s16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.s16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Spacing.s16),
        ])

        heart.image = UIImage(systemName: "heart.fill",
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        heart.tintColor = .terracotta
        heart.translatesAutoresizingMaskIntoConstraints = false
        heart.isHidden = true
        contentView.addSubview(heart)
        NSLayoutConstraint.activate([
            heart.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.s8),
            heart.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.s8),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with recipe: Recipe) {
        titleLabel.text = recipe.title
        descLabel.text = recipe.description
        let first = Array(recipe.ingredients.prefix(3))
        let overflow = recipe.ingredients.count - first.count
        var b = first.joined(separator: " · ")
        if overflow > 0 { b += " · +\(overflow)" }
        badges.text = b
        timeLabel.text = recipe.estimatedTime
        heart.isHidden = !recipe.isFavorite
    }
}
