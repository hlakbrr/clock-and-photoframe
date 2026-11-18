import UIKit

/// 容器控制器：在时钟与相框两个子页之间切换，下拉/双指长按进设置
final class MainViewController: UIViewController, ProbeEngineDelegate {

    private let engine = ProbeEngine()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        engine.delegate = self

        // 先显示时钟，随后 engine.start() 立即探测并纠正
        swap(to: ClockViewController())
        engine.start()

        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(openSettings))
        swipe.direction = .down
        view.addGestureRecognizer(swipe)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(openSettings))
        longPress.numberOfTouchesRequired = 2
        longPress.minimumPressDuration = 1.0
        view.addGestureRecognizer(longPress)
    }

    // MARK: ProbeEngineDelegate

    func probeEngine(_ engine: ProbeEngine, decidedFrameMode frame: Bool) {
        if frame {
            showFrame()
        } else {
            showClock()
        }
    }

    // MARK: 模式切换

    private func showClock() {
        guard !(children.first is ClockViewController) else { return }
        swap(to: ClockViewController())
    }

    private func showFrame() {
        guard !(children.first is FrameViewController) else { return }
        swap(to: FrameViewController())
    }

    private func swap(to vc: UIViewController) {
        children.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
        }
        addChild(vc)
        vc.view.frame = view.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(vc.view)
        vc.didMove(toParent: self)
    }

    // MARK: 设置

    @objc private func openSettings() {
        engine.stop()
        let vc = SettingsViewController()
        vc.onDismiss = { [weak self] in
            self?.engine.start()
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    /// 看门狗深链拉起：立即探测并按需重载相框页
    func handleDeepLink() {
        if engine.isFrameMode {
            (children.first as? FrameViewController)?.loadFrame()
        }
        engine.probeNow()
    }
}
