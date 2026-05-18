import UIKit

final class IngredientChipView: UIView {
    private let label = UILabel()
    private let removeButton = UIButton(type: .system)

    var onRemove: (() -> Void)?

    init(text: String) {
        super.init(frame: .zero)
        backgroundColor = .butter
        layer.cornerRadius = 14
        layer.masksToBounds = true

        label.text = text
        label.font = Typography.dmSans(14, weight: .medium)
        label.textColor = .ink

        removeButton.setTitle("×", for: .normal)
        removeButton.setTitleColor(.inkSoft, for: .normal)
        removeButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        removeButton.addTarget(self, action: #selector(tapRemove), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [label, removeButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Spacing.s4
        stack.layoutMargins = UIEdgeInsets(top: 6, left: Spacing.s12, bottom: 6, right: Spacing.s8)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapRemove() { onRemove?() }
}
