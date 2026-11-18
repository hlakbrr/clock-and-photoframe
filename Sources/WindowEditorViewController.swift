import UIKit

/// 单个探测时段的新增/编辑：两个时间滚轮（开始 / 结束）
final class WindowEditorViewController: UIViewController {

    var initial: ProbeWindow?
    var onSave: ((ProbeWindow) -> Void)?
    var onDelete: (() -> Void)?

    private let startPicker = UIDatePicker()
    private let endPicker = UIDatePicker()

    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = initial == nil ? "添加时段" : "编辑时段"
        view.backgroundColor = .black

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消", style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "保存", style: .done, target: self, action: #selector(saveTapped))

        for p in [startPicker, endPicker] {
            p.datePickerMode = .time
            p.preferredDatePickerStyle = .wheels
            p.translatesAutoresizingMaskIntoConstraints = false
        }
        if let initial = initial,
           let s = Settings.minutes(initial.start).map({ $0 / 60 * 3600 + $0 % 60 * 60 }),
           let e = Settings.minutes(initial.end).map({ $0 / 60 * 3600 + $0 % 60 * 60 }) {
            startPicker.setDate(Calendar.current.date(bySettingHour: s / 3600, minute: (s % 3600) / 60, second: 0, of: Date()) ?? Date(), animated: false)
            endPicker.setDate(Calendar.current.date(bySettingHour: e / 3600, minute: (e % 3600) / 60, second: 0, of: Date()) ?? Date(), animated: false)
        }

        let startLabel = makeCaption("开始")
        let endLabel = makeCaption("结束")

        var rows: [UIView] = [startLabel, startPicker, endLabel, endPicker]

        if initial != nil {
            let del = UIButton(type: .system)
            del.setTitle("删除这个时段", for: .normal)
            del.setTitleColor(.systemRed, for: .normal)
            del.heightAnchor.constraint(equalToConstant: 44).isActive = true
            del.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
            rows.append(del)
        }

        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func makeCaption(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.textColor = .lightGray
        l.font = .systemFont(ofSize: 13)
        return l
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        let start = fmt.string(from: startPicker.date)
        let end = fmt.string(from: endPicker.date)
        dismiss(animated: true) { [weak self] in
            self?.onSave?(ProbeWindow(start: start, end: end))
        }
    }

    @objc private func deleteTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onDelete?()
        }
    }

    override var prefersStatusBarHidden: Bool { false }
}
