import UIKit
import Combine

final class CreateEditRecipeVC: UIViewController {

    private let vm: CreateEditRecipeVM
    private var cancellables = Set<AnyCancellable>()

    private let scrollView = UIScrollView()
    private let formStack = UIStackView()

    private let titleField = UITextField()
    private let descriptionView = UITextView()
    private let descriptionPlaceholder = UILabel()
    private let ingredientsStack = UIStackView()
    private let stepsStack = UIStackView()
    private let timeField = UITextField()
    private let addIngredientButton = UIButton(type: .system)
    private let addStepButton = UIButton(type: .system)

    private lazy var saveButton: UIBarButtonItem = {
        let b = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveTapped))
        b.accessibilityIdentifier = "create.save.button"
        return b
    }()

    init(vm: CreateEditRecipeVM) {
        self.vm = vm
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .paper
        switch vm.mode {
        case .new: title = "New Recipe"
        case .edit: title = "Edit Recipe"
        }
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = saveButton

        setupScroll()
        buildForm()
        bind()
    }

    // MARK: - Layout

    private func setupScroll() {
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        formStack.axis = .vertical
        formStack.spacing = 6
        formStack.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 32, right: 16)
        formStack.isLayoutMarginsRelativeArrangement = true
        formStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(formStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            formStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            formStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            formStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            formStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            formStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func buildForm() {
        // TITLE
        formStack.addArrangedSubview(makeSectionLabel("Title *"))
        titleField.font = Typography.fraunces(22, weight: .bold)
        titleField.textColor = .ink
        titleField.placeholder = "Recipe title"
        titleField.accessibilityIdentifier = "create.title.field"
        titleField.accessibilityLabel = "Recipe title"
        titleField.borderStyle = .none
        titleField.backgroundColor = .clear
        titleField.addTarget(self, action: #selector(titleChanged), for: .editingChanged)
        let titleCard = makeFieldCard(titleField, minHeight: 52)
        formStack.addArrangedSubview(titleCard)
        formStack.setCustomSpacing(20, after: titleCard)

        // DESCRIPTION
        formStack.addArrangedSubview(makeSectionLabel("Description"))
        descriptionView.font = Typography.dmSans(16)
        descriptionView.textColor = .ink
        descriptionView.backgroundColor = .clear
        descriptionView.isScrollEnabled = false
        descriptionView.accessibilityIdentifier = "create.description.field"
        descriptionView.accessibilityLabel = "Description"
        descriptionView.delegate = self

        descriptionPlaceholder.text = "Optional notes, backstory, or cooking tips…"
        descriptionPlaceholder.font = Typography.dmSans(16)
        descriptionPlaceholder.textColor = UIColor.ink.withAlphaComponent(0.35)
        descriptionPlaceholder.numberOfLines = 0
        descriptionPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        descriptionPlaceholder.isUserInteractionEnabled = false
        descriptionView.addSubview(descriptionPlaceholder)
        NSLayoutConstraint.activate([
            descriptionPlaceholder.topAnchor.constraint(equalTo: descriptionView.topAnchor, constant: 8),
            descriptionPlaceholder.leadingAnchor.constraint(equalTo: descriptionView.leadingAnchor, constant: 5),
            descriptionPlaceholder.trailingAnchor.constraint(equalTo: descriptionView.trailingAnchor, constant: -5),
        ])
        let descCard = makeFieldCard(descriptionView, minHeight: 110)
        descriptionView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        formStack.addArrangedSubview(descCard)
        formStack.setCustomSpacing(20, after: descCard)

        // INGREDIENTS
        formStack.addArrangedSubview(makeSectionLabel("Ingredients"))
        ingredientsStack.axis = .vertical
        ingredientsStack.spacing = 0
        let ingredientsCard = makeListCard(
            listStack: ingredientsStack,
            addButton: addIngredientButton,
            addButtonId: "create.ingredient.add",
            addTitle: "+ Add ingredient"
        )
        addIngredientButton.addTarget(self, action: #selector(addIngredientTapped), for: .touchUpInside)
        formStack.addArrangedSubview(ingredientsCard)
        formStack.setCustomSpacing(20, after: ingredientsCard)

        // STEPS
        formStack.addArrangedSubview(makeSectionLabel("Steps"))
        stepsStack.axis = .vertical
        stepsStack.spacing = 0
        let stepsCard = makeListCard(
            listStack: stepsStack,
            addButton: addStepButton,
            addButtonId: "create.step.add",
            addTitle: "+ Add step"
        )
        addStepButton.addTarget(self, action: #selector(addStepTapped), for: .touchUpInside)
        formStack.addArrangedSubview(stepsCard)
        formStack.setCustomSpacing(20, after: stepsCard)

        // TIME
        formStack.addArrangedSubview(makeSectionLabel("Estimated Time"))
        timeField.font = Typography.dmSans(16)
        timeField.textColor = .ink
        timeField.placeholder = "e.g. 30 min"
        timeField.accessibilityIdentifier = "create.time.field"
        timeField.accessibilityLabel = "Estimated time"
        timeField.borderStyle = .none
        timeField.backgroundColor = .clear
        timeField.addTarget(self, action: #selector(timeChanged), for: .editingChanged)
        let timeCard = makeFieldCard(timeField, minHeight: 52)
        formStack.addArrangedSubview(timeCard)

        // DELETE (edit mode only) — Contacts-style destructive action at the bottom
        if case .edit = vm.mode {
            var config = UIButton.Configuration.plain()
            config.title = "Delete Recipe"
            config.image = UIImage(systemName: "trash")
            config.imagePadding = 8
            config.baseForegroundColor = .terracotta
            let deleteButton = UIButton(configuration: config)
            deleteButton.accessibilityIdentifier = "create.delete.button"
            deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
            formStack.setCustomSpacing(32, after: timeCard)
            formStack.addArrangedSubview(deleteButton)
        }

        // Populate
        titleField.text = vm.title
        descriptionView.text = vm.descriptionText
        descriptionPlaceholder.isHidden = !vm.descriptionText.isEmpty
        timeField.text = vm.estimatedTime
        rebuildIngredientRows()
        rebuildStepRows()
    }

    // MARK: - Dynamic rows

    private func rebuildIngredientRows() {
        ingredientsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (idx, text) in vm.ingredients.enumerated() {
            ingredientsStack.addArrangedSubview(makeRow(
                text: text,
                fieldId: "create.ingredient.row.\(idx).field",
                removeId: "create.ingredient.row.\(idx).remove",
                axLabel: "Ingredient \(idx + 1)",
                index: idx,
                isStep: false,
                canRemove: vm.ingredients.count > 1
            ))
        }
    }

    private func rebuildStepRows() {
        stepsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (idx, text) in vm.steps.enumerated() {
            stepsStack.addArrangedSubview(makeRow(
                text: text,
                fieldId: "create.step.row.\(idx).field",
                removeId: "create.step.row.\(idx).remove",
                axLabel: "Step \(idx + 1)",
                index: idx,
                isStep: true,
                canRemove: vm.steps.count > 1
            ))
        }
    }

    private func makeRow(text: String, fieldId: String, removeId: String,
                         axLabel: String, index: Int, isStep: Bool, canRemove: Bool) -> UIView {
        let container = UIView()

        let field = UITextField()
        field.font = Typography.dmSans(16)
        field.textColor = .ink
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.text = text
        field.accessibilityIdentifier = fieldId
        field.accessibilityLabel = axLabel
        field.tag = index
        field.addTarget(self,
                        action: isStep ? #selector(stepFieldChanged(_:)) : #selector(ingredientFieldChanged(_:)),
                        for: .editingChanged)
        field.translatesAutoresizingMaskIntoConstraints = false

        let minus = UIButton(type: .system)
        minus.setImage(UIImage(systemName: "minus.circle.fill"), for: .normal)
        minus.tintColor = .terracotta
        minus.accessibilityIdentifier = removeId
        minus.accessibilityLabel = "Remove \(axLabel.lowercased())"
        minus.tag = index
        minus.isEnabled = canRemove
        minus.alpha = canRemove ? 1.0 : 0.3
        minus.addTarget(self,
                        action: isStep ? #selector(removeStepRowTapped(_:)) : #selector(removeIngredientRowTapped(_:)),
                        for: .touchUpInside)
        minus.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(field)
        container.addSubview(minus)
        NSLayoutConstraint.activate([
            minus.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            minus.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            minus.widthAnchor.constraint(equalToConstant: 24),
            minus.heightAnchor.constraint(equalToConstant: 24),

            field.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(equalTo: minus.leadingAnchor, constant: -8),
            field.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            field.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])

        let sep = UIView()
        sep.backgroundColor = .rule
        sep.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            sep.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),
        ])

        return container
    }

    // MARK: - UI Helpers

    private func makeSectionLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text.uppercased()
        l.font = Typography.dmSans(12, weight: .medium)
        l.textColor = .inkSoft
        return l
    }

    private func makeFieldCard(_ field: UIView, minHeight: CGFloat = 44) -> UIView {
        let card = UIView()
        card.backgroundColor = .paper2
        card.layer.cornerRadius = 12
        card.clipsToBounds = true
        field.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(field)
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            field.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            field.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight),
        ])
        return card
    }

    private func makeListCard(listStack: UIStackView, addButton: UIButton,
                              addButtonId: String, addTitle: String) -> UIView {
        let card = UIStackView()
        card.axis = .vertical
        card.spacing = 0
        card.backgroundColor = .paper2
        card.layer.cornerRadius = 12
        card.clipsToBounds = true

        card.addArrangedSubview(listStack)

        addButton.setTitle(addTitle, for: .normal)
        addButton.tintColor = .sage
        addButton.accessibilityIdentifier = addButtonId
        addButton.contentHorizontalAlignment = .leading

        let addRow = UIView()
        addRow.heightAnchor.constraint(equalToConstant: 44).isActive = true
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addRow.addSubview(addButton)
        NSLayoutConstraint.activate([
            addButton.leadingAnchor.constraint(equalTo: addRow.leadingAnchor, constant: 16),
            addButton.centerYAnchor.constraint(equalTo: addRow.centerYAnchor),
            addButton.trailingAnchor.constraint(equalTo: addRow.trailingAnchor, constant: -16),
        ])
        card.addArrangedSubview(addRow)

        return card
    }

    // MARK: - Actions

    @objc private func titleChanged() {
        vm.title = titleField.text ?? ""
        syncSaveButton()
    }
    @objc private func timeChanged() { vm.estimatedTime = timeField.text ?? "" }

    @objc private func ingredientFieldChanged(_ sender: UITextField) {
        var arr = vm.ingredients
        guard arr.indices.contains(sender.tag) else { return }
        arr[sender.tag] = sender.text ?? ""
        vm.ingredients = arr
        syncSaveButton()
    }
    @objc private func stepFieldChanged(_ sender: UITextField) {
        var arr = vm.steps
        guard arr.indices.contains(sender.tag) else { return }
        arr[sender.tag] = sender.text ?? ""
        vm.steps = arr
        syncSaveButton()
    }

    private func syncSaveButton() {
        saveButton.isEnabled = vm.isValid
    }

    @objc private func addIngredientTapped() {
        vm.addIngredientRow()
        rebuildIngredientRows()
    }
    @objc private func removeIngredientRowTapped(_ sender: UIButton) {
        vm.removeIngredientRow(at: sender.tag)
        rebuildIngredientRows()
    }
    @objc private func addStepTapped() {
        vm.addStepRow()
        rebuildStepRows()
    }
    @objc private func removeStepRowTapped(_ sender: UIButton) {
        vm.removeStepRow(at: sender.tag)
        rebuildStepRows()
    }

    @objc private func cancelTapped() {
        guard vm.hasUnsavedChanges else {
            navigationController?.popViewController(animated: true); return
        }
        let alert = UIAlertController(title: "Discard changes?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Keep editing", style: .cancel))
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    @objc private func saveTapped() {
        Task { await vm.save() }
    }

    @objc private func deleteTapped() {
        let alert = UIAlertController(title: "Delete this recipe?",
                                      message: "This can't be undone.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            Task {
                if await self?.vm.delete() == true {
                    // The recipe (and possibly its batch) is gone; the detail/batch
                    // screens behind us are now stale, so return to the list.
                    self?.navigationController?.popToRootViewController(animated: true)
                }
            }
        })
        present(alert, animated: true)
    }

    // MARK: - Bindings

    private func bind() {
        vm.$isValid
            .sink { [weak self] in self?.saveButton.isEnabled = $0 }
            .store(in: &cancellables)

        vm.$saveState
            .sink { [weak self] state in self?.handle(state: state) }
            .store(in: &cancellables)
    }

    private func handle(state: CreateEditRecipeVM.SaveState) {
        switch state {
        case .idle:
            break
        case .saving:
            saveButton.isEnabled = false
        case .saved:
            navigationController?.popViewController(animated: true)
        case .error(let msg):
            let alert = UIAlertController(title: "Couldn't save", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            saveButton.isEnabled = vm.isValid
        }
    }
}

extension CreateEditRecipeVC: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        vm.descriptionText = textView.text ?? ""
        descriptionPlaceholder.isHidden = !textView.text.isEmpty
    }
}
