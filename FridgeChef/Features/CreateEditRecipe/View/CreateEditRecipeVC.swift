import UIKit
import Combine

final class CreateEditRecipeVC: UIViewController {

    private let vm: CreateEditRecipeVM
    private var cancellables = Set<AnyCancellable>()

    private let scrollView = UIScrollView()
    private let formStack = UIStackView()

    private let titleField = UITextField()
    private let descriptionView = UITextView()
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
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                           target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = saveButton

        setupScroll()
        buildForm()
        bind()
    }

    private func setupScroll() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        formStack.axis = .vertical
        formStack.spacing = Spacing.s16
        formStack.layoutMargins = UIEdgeInsets(top: Spacing.s24, left: Spacing.s24,
                                               bottom: Spacing.s24, right: Spacing.s24)
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
        titleField.font = Typography.fraunces(28, weight: .bold)
        titleField.textColor = .ink
        titleField.placeholder = "Recipe title"
        titleField.accessibilityIdentifier = "create.title.field"
        titleField.accessibilityLabel = "Recipe title"
        titleField.borderStyle = .none
        titleField.addTarget(self, action: #selector(titleChanged), for: .editingChanged)
        formStack.addArrangedSubview(titleField)
        formStack.addArrangedSubview(makeRule())

        formStack.addArrangedSubview(makeSectionHeader("Description"))
        descriptionView.font = Typography.dmSans(16)
        descriptionView.textColor = .ink
        descriptionView.backgroundColor = .clear
        descriptionView.isScrollEnabled = false
        descriptionView.accessibilityIdentifier = "create.description.field"
        descriptionView.accessibilityLabel = "Description"
        descriptionView.delegate = self
        descriptionView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        formStack.addArrangedSubview(descriptionView)
        formStack.addArrangedSubview(makeRule())

        formStack.addArrangedSubview(makeSectionHeader("Ingredients"))
        ingredientsStack.axis = .vertical
        ingredientsStack.spacing = Spacing.s8
        formStack.addArrangedSubview(ingredientsStack)
        addIngredientButton.setTitle("+ Add ingredient", for: .normal)
        addIngredientButton.tintColor = .sage
        addIngredientButton.accessibilityIdentifier = "create.ingredient.add"
        addIngredientButton.addTarget(self, action: #selector(addIngredientTapped), for: .touchUpInside)
        formStack.addArrangedSubview(addIngredientButton)
        formStack.addArrangedSubview(makeRule())

        formStack.addArrangedSubview(makeSectionHeader("Steps"))
        stepsStack.axis = .vertical
        stepsStack.spacing = Spacing.s8
        formStack.addArrangedSubview(stepsStack)
        addStepButton.setTitle("+ Add step", for: .normal)
        addStepButton.tintColor = .sage
        addStepButton.accessibilityIdentifier = "create.step.add"
        addStepButton.addTarget(self, action: #selector(addStepTapped), for: .touchUpInside)
        formStack.addArrangedSubview(addStepButton)
        formStack.addArrangedSubview(makeRule())

        formStack.addArrangedSubview(makeSectionHeader("Estimated time"))
        timeField.font = Typography.dmSans(16)
        timeField.textColor = .ink
        timeField.placeholder = "30 min"
        timeField.accessibilityIdentifier = "create.time.field"
        timeField.accessibilityLabel = "Estimated time"
        timeField.borderStyle = .none
        timeField.addTarget(self, action: #selector(timeChanged), for: .editingChanged)
        formStack.addArrangedSubview(timeField)

        titleField.text = vm.title
        descriptionView.text = vm.descriptionText
        timeField.text = vm.estimatedTime
        rebuildIngredientRows()
        rebuildStepRows()
    }

    private func rebuildIngredientRows() {
        ingredientsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (idx, text) in vm.ingredients.enumerated() {
            ingredientsStack.addArrangedSubview(makeRow(text: text,
                                                       fieldId: "create.ingredient.row.\(idx).field",
                                                       removeId: "create.ingredient.row.\(idx).remove",
                                                       axLabel: "Ingredient \(idx + 1)",
                                                       index: idx,
                                                       isStep: false,
                                                       canRemove: vm.ingredients.count > 1))
        }
    }

    private func rebuildStepRows() {
        stepsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (idx, text) in vm.steps.enumerated() {
            stepsStack.addArrangedSubview(makeRow(text: text,
                                                  fieldId: "create.step.row.\(idx).field",
                                                  removeId: "create.step.row.\(idx).remove",
                                                  axLabel: "Step \(idx + 1)",
                                                  index: idx,
                                                  isStep: true,
                                                  canRemove: vm.steps.count > 1))
        }
    }

    private func makeRow(text: String, fieldId: String, removeId: String,
                         axLabel: String, index: Int, isStep: Bool, canRemove: Bool) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Spacing.s8

        let field = UITextField()
        field.font = Typography.dmSans(16)
        field.textColor = .ink
        field.borderStyle = .roundedRect
        field.text = text
        field.accessibilityIdentifier = fieldId
        field.accessibilityLabel = axLabel
        field.tag = index
        field.addTarget(self,
                        action: isStep ? #selector(stepFieldChanged(_:)) : #selector(ingredientFieldChanged(_:)),
                        for: .editingChanged)
        row.addArrangedSubview(field)

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
        minus.widthAnchor.constraint(equalToConstant: 28).isActive = true
        row.addArrangedSubview(minus)
        return row
    }

    @objc private func titleChanged() { vm.title = titleField.text ?? "" }
    @objc private func timeChanged() { vm.estimatedTime = timeField.text ?? "" }

    @objc private func ingredientFieldChanged(_ sender: UITextField) {
        var arr = vm.ingredients
        guard arr.indices.contains(sender.tag) else { return }
        arr[sender.tag] = sender.text ?? ""
        vm.ingredients = arr
    }
    @objc private func stepFieldChanged(_ sender: UITextField) {
        var arr = vm.steps
        guard arr.indices.contains(sender.tag) else { return }
        arr[sender.tag] = sender.text ?? ""
        vm.steps = arr
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

    private func makeSectionHeader(_ text: String) -> UIView {
        let l = UILabel()
        l.text = text
        l.font = Typography.fraunces(20, weight: .bold)
        l.textColor = .ink
        return l
    }

    private func makeRule() -> UIView {
        let v = UIView()
        v.backgroundColor = .rule
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }
}

extension CreateEditRecipeVC: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        vm.descriptionText = textView.text ?? ""
    }
}
