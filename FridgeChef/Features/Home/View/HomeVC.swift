import UIKit
import Combine
import PhotosUI

final class HomeVC: UIViewController, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {

    private let vm: HomeVM
    private var cancellables = Set<AnyCancellable>()

    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let chipContainer = UIStackView()
    private let inputField = UITextField()
    private let addButton = UIButton(type: .system)
    private let suggestButton = UIButton(type: .system)
    private let cameraItem = UIBarButtonItem(image: UIImage(systemName: "camera"), style: .plain, target: nil, action: nil)
    private var overlay: UIView?

    init(vm: HomeVM) {
        self.vm = vm
        super.init(nibName: nil, bundle: nil)
        title = "FridgeChef"
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .paper
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.rightBarButtonItem = cameraItem
        cameraItem.target = self
        cameraItem.action = #selector(tapCamera)

        buildLayout()
        bind()
    }

    private func buildLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        content.axis = .vertical
        content.spacing = Spacing.s16
        content.layoutMargins = UIEdgeInsets(top: Spacing.s16, left: Spacing.s16, bottom: Spacing.s16, right: Spacing.s16)
        content.isLayoutMarginsRelativeArrangement = true
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scrollView.topAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        let header = UILabel()
        header.text = "INGREDIENTS"
        header.font = Typography.dmSans(12, weight: .medium)
        header.textColor = .inkSoft
        content.addArrangedSubview(header)

        chipContainer.axis = .vertical
        chipContainer.spacing = Spacing.s8
        content.addArrangedSubview(chipContainer)

        let inputRow = UIStackView()
        inputRow.axis = .horizontal
        inputRow.spacing = Spacing.s8
        inputRow.alignment = .center
        inputField.placeholder = "Add an ingredient…"
        inputField.font = Typography.dmSans(15)
        inputField.borderStyle = .roundedRect
        inputField.returnKeyType = .done
        inputField.delegate = self
        inputField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addButton.setTitle("Add", for: .normal)
        addButton.titleLabel?.font = Typography.dmSans(15, weight: .medium)
        addButton.addTarget(self, action: #selector(tapAdd), for: .touchUpInside)
        inputRow.addArrangedSubview(inputField)
        inputRow.addArrangedSubview(addButton)
        content.addArrangedSubview(inputRow)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        content.addArrangedSubview(spacer)

        suggestButton.setTitle("Suggest recipes →", for: .normal)
        suggestButton.titleLabel?.font = Typography.fraunces(18, weight: .bold)
        suggestButton.backgroundColor = .sage
        suggestButton.setTitleColor(.paper, for: .normal)
        suggestButton.layer.cornerRadius = 12
        suggestButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        suggestButton.addTarget(self, action: #selector(tapSuggest), for: .touchUpInside)
        content.addArrangedSubview(suggestButton)

        // a11y identifiers for XCUITest
        inputField.accessibilityIdentifier = "home.inputField"
        addButton.accessibilityIdentifier = "home.addButton"
        suggestButton.accessibilityIdentifier = "home.suggestButton"
        view.accessibilityIdentifier = "home.root"
    }

    private func bind() {
        vm.$chips
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.renderChips($0) }
            .store(in: &cancellables)

        vm.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.render(state: $0) }
            .store(in: &cancellables)

        vm.$chips
            .receive(on: DispatchQueue.main)
            .map { !$0.isEmpty }
            .sink { [weak self] enabled in
                self?.suggestButton.isEnabled = enabled
                self?.suggestButton.alpha = enabled ? 1 : 0.5
            }
            .store(in: &cancellables)
    }

    private func renderChips(_ chips: [String]) {
        chipContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if chips.isEmpty {
            let helper = UILabel()
            helper.text = "Add ingredients or tap 📷 to start"
            helper.font = Typography.dmSans(14)
            helper.textColor = .inkSoft
            chipContainer.addArrangedSubview(helper)
            return
        }
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = Spacing.s8
        row.alignment = .leading
        row.distribution = .fillProportionally
        for chip in chips {
            let view = IngredientChipView(text: chip)
            view.onRemove = { [weak self] in self?.vm.removeChip(chip) }
            row.addArrangedSubview(view)
        }
        chipContainer.addArrangedSubview(row)
    }

    private func render(state: HomeVM.State) {
        switch state {
        case .idle:
            hideOverlay()
        case .loading:
            showOverlay()
        case .loaded(let batch):
            hideOverlay()
            let vc = RecipeBatchVC(vm: RecipeBatchVM(batch: batch))
            navigationController?.pushViewController(vc, animated: true)
            NotificationCenter.default.post(name: .recipesDidChange, object: nil)
        case .error(let msg):
            hideOverlay()
            let alert = UIAlertController(title: "Couldn't generate", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    private func showOverlay() {
        guard overlay == nil else { return }
        let v = UIView(frame: view.bounds)
        v.backgroundColor = UIColor.ink.withAlphaComponent(0.6)
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .paper
        spinner.startAnimating()
        let label = UILabel()
        label.text = "Reading your kitchen…"
        label.textColor = .paper
        label.font = Typography.fraunces(18, weight: .regular)

        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Spacing.s16
        stack.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: v.centerYAnchor),
        ])

        view.addSubview(v)
        overlay = v
    }

    private func hideOverlay() {
        overlay?.removeFromSuperview()
        overlay = nil
    }

    // MARK: - actions

    @objc private func tapAdd() {
        guard let text = inputField.text else { return }
        vm.addChip(text)
        inputField.text = ""
    }

    @objc private func tapSuggest() {
        view.endEditing(true)
        vm.generate()
    }

    @objc private func tapCamera() {
        PhotoSourceActionSheet.present(on: self) { [weak self] source in
            self?.presentPicker(source: source)
        }
    }

    private func presentPicker(source: PhotoSource) {
        switch source {
        case .camera:
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            present(picker, animated: true)
        case .library:
            var config = PHPickerConfiguration()
            config.selectionLimit = 1
            config.filter = .images
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            present(picker, animated: true)
        }
    }

    // MARK: - PHPickerViewControllerDelegate

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let image = obj as? UIImage else { return }
            DispatchQueue.main.async { self?.vm.generate(image: image) }
        }
    }

    // MARK: - UIImagePickerControllerDelegate (camera)

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            vm.generate(image: image)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        tapAdd()
        return false
    }
}

extension Notification.Name {
    static let recipesDidChange = Notification.Name("com.baha.fridgechef.recipesDidChange")
}
