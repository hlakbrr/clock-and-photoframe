import UIKit

/// 极简时钟（Zen Flip Clock 风格的干净重写）：
/// 纯黑背景 + 细体白色大数字 + 一行浅灰日期，数字变化时自上翻转
final class ClockViewController: UIViewController {

    private let timeLabel = UILabel()
    private let dateLabel = UILabel()
    private var timer: Timer?
    private var lastTimeText = ""

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        timeLabel.font = .systemFont(ofSize: 120, weight: .light)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .center
        timeLabel.adjustsFontSizeToFitWidth = true
        timeLabel.minimumScaleFactor = 0.4

        dateLabel.font = .systemFont(ofSize: 16, weight: .light)
        dateLabel.textColor = UIColor(white: 0.72, alpha: 1)
        dateLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [timeLabel, dateLabel])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
        ])

        refresh(flip: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh(flip: true)
        }
        refresh(flip: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    private func refresh(flip: Bool) {
        let now = Date()
        var fmt = Settings.use24Hour ? "HH:mm" : "h:mm"
        if Settings.showSeconds { fmt += ":ss" }
        timeFormatter.dateFormat = fmt
        let t = timeFormatter.string(from: now)
        if t != lastTimeText {
            if flip && !lastTimeText.isEmpty {
                UIView.transition(with: timeLabel,
                                  duration: 0.55,
                                  options: [.transitionFlipFromTop],
                                  animations: { self.timeLabel.text = t })
            } else {
                timeLabel.text = t
            }
            lastTimeText = t
        }

        timeFormatter.dateFormat = "M月d日 EEEE"
        dateLabel.text = timeFormatter.string(from: now)
        dateLabel.isHidden = !Settings.showDate
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
}
