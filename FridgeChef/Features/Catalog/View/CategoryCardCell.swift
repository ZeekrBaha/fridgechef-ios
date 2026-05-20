import UIKit

/// One card in the catalog grid. Shows a title and an optional
/// "Today: <pick>" subtitle. Used for all four cards (meals + fridge).
final class CategoryCardCell: UICollectionViewCell {

    static let reuseID = "CategoryCardCell"

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = Typography.title
        l.textColor = .ink
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = Typography.body
        l.textColor = .inkSoft
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .paper2
        contentView.layer.cornerRadius = 12
        contentView.layer.cornerCurve = .continuous

        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.s16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.s16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.s16),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Spacing.s16)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Configure for a meal card.
    /// - Parameters:
    ///   - title: "Breakfast ideas" etc.
    ///   - pick: today's recipe title or nil; if nil, subtitle shows placeholder
    func configure(title: String, pick: String?) {
        titleLabel.text = title
        if let pick {
            subtitleLabel.text = "Today: \(pick)"
        } else {
            subtitleLabel.text = "Loading…"
        }
    }

    /// Configure for the static "From my fridge" card (no AI pick).
    func configureFridge() {
        titleLabel.text = "From my\nfridge"
        subtitleLabel.text = "Snap a photo"
    }
}
