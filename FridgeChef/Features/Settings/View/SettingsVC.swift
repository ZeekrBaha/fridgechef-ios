import UIKit

final class SettingsVC: UITableViewController {

    private let vm: SettingsVM

    private enum Section: Int, CaseIterable { case appearance, api, data, about }

    init(vm: SettingsVM) {
        self.vm = vm
        super.init(style: .insetGrouped)
        title = "Settings"
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .paper
        tableView.backgroundColor = .paper
        navigationController?.navigationBar.prefersLargeTitles = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .appearance: return "APPEARANCE"
        case .api:        return "API"
        case .data:       return "DATA"
        case .about:      return "ABOUT"
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .appearance: return 1
        case .api:        return 2
        case .data:       return 1
        case .about:      return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        cell.backgroundColor = .paper2
        cell.selectionStyle = .none
        cell.accessoryView = nil
        cell.accessoryType = .none

        switch (Section(rawValue: indexPath.section)!, indexPath.row) {
        case (.appearance, 0):
            var content = cell.defaultContentConfiguration()
            content.text = "Theme"
            cell.contentConfiguration = content
            let seg = UISegmentedControl(items: ["System", "Light", "Dark"])
            seg.selectedSegmentIndex = vm.currentTheme.rawValue
            seg.addTarget(self, action: #selector(themeChanged(_:)), for: .valueChanged)
            cell.accessoryView = seg

        case (.api, 0):
            var content = cell.defaultContentConfiguration()
            content.text = "OpenAI key"
            content.secondaryText = vm.apiKeyStatus == .present ? "✓ injected" : "⚠ missing"
            content.secondaryTextProperties.color = vm.apiKeyStatus == .present ? .sage : .terracotta
            cell.contentConfiguration = content

        case (.api, 1):
            var content = cell.defaultContentConfiguration()
            content.text = "Model"
            content.secondaryText = vm.modelName
            cell.contentConfiguration = content

        case (.data, 0):
            var content = cell.defaultContentConfiguration()
            content.text = "Clear all recipes"
            content.textProperties.color = .terracotta
            cell.contentConfiguration = content
            cell.selectionStyle = .default

        case (.about, 0):
            var content = cell.defaultContentConfiguration()
            content.text = "Version"
            content.secondaryText = vm.versionString
            cell.contentConfiguration = content

        default:
            break
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if Section(rawValue: indexPath.section) == .data, indexPath.row == 0 {
            confirmClearAll()
        }
    }

    @objc private func themeChanged(_ sender: UISegmentedControl) {
        guard let style = ThemeManager.Style(rawValue: sender.selectedSegmentIndex) else { return }
        vm.setTheme(style)
    }

    private func confirmClearAll() {
        let alert = UIAlertController(
            title: "Clear all recipes?",
            message: "This deletes every saved recipe batch. Cannot be undone.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear all", style: .destructive) { [weak self] _ in
            Task { await self?.vm.clearAll() }
        })
        present(alert, animated: true)
    }
}
