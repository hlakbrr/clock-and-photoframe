import UIKit

/// 设置页：相框服务器 / 自动切换（探测间隔 + 时段列表）/ 时钟外观
final class SettingsViewController: UIViewController {

    var onDismiss: (() -> Void)?

    private var windows: [ProbeWindow] = Settings.probeWindows

    private let urlField: UITextField = {
        let f = UITextField()
        f.placeholder = "例如 192.168.1.10:8080 或 http://…"
        f.borderStyle = .roundedRect
        f.autocorrectionType = .no
        f.autocapitalizationType = .none
        f.keyboardType = .URL
        f.clearButtonMode = .whileEditing
        f.backgroundColor = UIColor(white: 0.18, alpha: 1)
        f.textColor = .white
        f.keyboardAppearance = .dark
        return f
    }()

    private let secretField: UITextField = {
        let f = UITextField()
        f.placeholder = "留空表示不使用认证（可选）"
        f.borderStyle = .roundedRect
        f.autocorrectionType = .no
        f.autocapitalizationType = .none
        f.clearButtonMode = .whileEditing
        f.backgroundColor = UIColor(white: 0.18, alpha: 1)
        f.textColor = .white
        f.keyboardAppearance = .dark
        return f
    }()

    private let intervalSegment = UISegmentedControl(items: ["30秒", "1分钟", "2分钟", "5分钟"])
    private let windowsStack = UIStackView()
    private let secondsSwitch = UISwitch()
    private let h24Switch = UISwitch()
    private let dateSwitch = UISwitch()

    private let intervalValues = [30, 60, 120, 300]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        view.backgroundColor = .black

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "关闭", style: .plain, target: self, action: #selector(closeTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "保存", style: .done, target: self, action: #selector(saveTapped))

        urlField.text = Settings.serverURL
        secretField.text = Settings.authSecret

        let savedInterval = Settings.probeInterval
        intervalSegment.selectedSegmentIndex =
            intervalValues.firstIndex(of: savedInterval).map { min($0, intervalValues.count - 1) } ?? 1
        secondsSwitch.isOn = Settings.showSeconds
        h24Switch.isOn = Settings.use24Hour
        dateSwitch.isOn = Settings.showDate

        renderWindows()

        let content = UIStackView(arrangedSubviews: [
            sectionLabel("相框服务器"),
            fieldLabel("服务器地址"), urlField,
            fieldLabel("认证密钥 authSecret"), secretField,

            sectionLabel("自动切换"),
            fieldLabel("探测间隔"), intervalSegment,
            fieldLabel("探测时段（时段外始终显示时钟；列表为空表示全天探测）"),
            windowsStack,
            addWindowButton(),

            sectionLabel("时钟外观"),
            switchRow("24 小时制", h24Switch),
            switchRow("显示秒", secondsSwitch),
            switchRow("显示日期", dateSwitch),

            hintLabel,
        ])
        content.axis = .vertical
        content.spacing = 10

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(content)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40),
        ])
    }

    // MARK: - 界面元素

    private let hintLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 0
        l.font = .systemFont(ofSize: 13)
        l.textColor = .lightGray
        l.text = "自动切换逻辑：在探测时段内每隔设定间隔探测一次服务器，在线自动切到相框、离线自动切回时钟；时段外始终显示时钟。保存后立即生效。\n\n进设置：时钟或相框画面上下拉，或双指长按 1 秒。"
        return l
    }()

    private func sectionLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.textColor = UIColor(white: 1, alpha: 1)
        l.font = .boldSystemFont(ofSize: 17)
        return l
    }

    private func fieldLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.textColor = .lightGray
        l.font = .systemFont(ofSize: 13)
        return l
    }

    private func switchRow(_ title: String, _ sw: UISwitch) -> UIView {
        let l = UILabel()
        l.text = title
        l.textColor = .white
        l.font = .systemFont(ofSize: 15)
        let row = UIStackView(arrangedSubviews: [l, UIView(), sw])
        row.axis = .horizontal
        row.spacing = 8
        return row
    }

    private func addWindowButton() -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle("＋ 添加时段", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = UIColor(white: 0.18, alpha: 1)
        b.layer.cornerRadius = 8
        b.heightAnchor.constraint(equalToConstant: 40).isActive = true
        b.addTarget(self, action: #selector(addWindowTapped), for: .touchUpInside)
        return b
    }

    // MARK: - 时段列表

    private func renderWindows() {
        windowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        windowsStack.axis = .vertical
        windowsStack.spacing = 6

        for (i, w) in windows.enumerated() {
            let label = UILabel()
            label.text = "\(w.start) ~ \(w.end)"
            label.textColor = .white
            label.font = .systemFont(ofSize: 15)
            let edit = UIButton(type: .system)
            edit.setTitle("编辑", for: .normal)
            edit.tag = i
            edit.addTarget(self, action: #selector(editWindowTapped(_:)), for: .touchUpInside)
            let del = UIButton(type: .system)
            del.setTitle("删除", for: .normal)
            del.setTitleColor(.systemRed, for: .normal)
            del.tag = i
            del.addTarget(self, action: #selector(deleteWindowTapped(_:)), for: .touchUpInside)
            let row = UIStackView(arrangedSubviews: [label, UIView(), edit, del])
            row.axis = .horizontal
            row.spacing = 12
            row.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            row.isLayoutMarginsRelativeArrangement = true
            row.backgroundColor = UIColor(white: 0.14, alpha: 1)
            row.layer.cornerRadius = 8
            windowsStack.addArrangedSubview(row)
        }
        if windows.isEmpty {
            let l = UILabel()
            l.text = "（空 = 全天探测）"
            l.textColor = .lightGray
            l.font = .systemFont(ofSize: 13)
            windowsStack.addArrangedSubview(l)
        }
    }

    @objc private func addWindowTapped() {
        presentEditor(initial: nil, index: nil)
    }

    @objc private func editWindowTapped(_ sender: UIButton) {
        let i = sender.tag
        guard i < windows.count else { return }
        presentEditor(initial: windows[i], index: i)
    }

    @objc private func deleteWindowTapped(_ sender: UIButton) {
        let i = sender.tag
        guard i < windows.count else { return }
        windows.remove(at: i)
        renderWindows()
    }

    private func presentEditor(initial: ProbeWindow?, index: Int?) {
        let editor = WindowEditorViewController()
        editor.initial = initial
        editor.onSave = { [weak self] w in
            guard let self = self else { return }
            if let i = index { self.windows[i] = w } else { self.windows.append(w) }
            self.renderWindows()
        }
        editor.onDelete = { [weak self] in
            guard let self = self, let i = index else { return }
            self.windows.remove(at: i)
            self.renderWindows()
        }
        let nav = UINavigationController(rootViewController: editor)
        nav.modalPresentationStyle = .automatic
        present(nav, animated: true)
    }

    // MARK: - 保存 / 关闭

    @objc private func closeTapped() {
        dismiss(animated: true) { [weak self] in self?.onDismiss?() }
    }

    @objc private func saveTapped() {
        let url = (urlField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else {
            let alert = UIAlertController(title: "地址不能为空", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好", style: .default))
            present(alert, animated: true)
            return
        }
        Settings.save(url: url, secret: secretField.text ?? "")
        Settings.save(interval: intervalValues[intervalSegment.selectedSegmentIndex])
        Settings.save(windows: windows)
        Settings.save(showSeconds: secondsSwitch.isOn)
        Settings.save(use24Hour: h24Switch.isOn)
        Settings.save(showDate: dateSwitch.isOn)
        dismiss(animated: true) { [weak self] in self?.onDismiss?() }
    }

    override var prefersStatusBarHidden: Bool { false }
}
