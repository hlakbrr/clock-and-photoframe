import Foundation

protocol ProbeEngineDelegate: AnyObject {
    /// 探测决策：true = 显示相框，false = 显示时钟（仅在模式变化时回调）
    func probeEngine(_ engine: ProbeEngine, decidedFrameMode frame: Bool)
}

/// 按用户设置的时段和间隔探测 NAS：
/// - 时段内：HEAD 探测服务器，在线 → 相框，离线 → 时钟
/// - 时段外：时钟（不探测）
/// - 未配置服务器地址：永远时钟
final class ProbeEngine {

    weak var delegate: ProbeEngineDelegate?

    private(set) var isFrameMode = false
    private var timer: Timer?
    private var inFlight = false

    /// 启动探测循环（首次立即探测一次）
    func start() {
        stopTimer()
        let interval = Double(Settings.probeInterval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    func stop() {
        stopTimer()
    }

    /// 立即探测一次（深链拉起/设置保存后调用）
    func probeNow() {
        tick()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard !inFlight else { return }
        guard Settings.serverURL != nil else {
            setMode(frame: false)
            return
        }
        guard Settings.isWithinProbeWindow() else {
            setMode(frame: false)
            return
        }
        inFlight = true
        Self.checkReachable { [weak self] online in
            self?.inFlight = false
            self?.setMode(frame: online)
        }
    }

    private func setMode(frame: Bool) {
        let changed = (frame != isFrameMode)
        isFrameMode = frame
        if changed {
            delegate?.probeEngine(self, decidedFrameMode: frame)
        }
    }

    /// HEAD 请求：任何 HTTP 响应都算在线（对齐安卓版 Helpers.isServerReachable）
    private static func checkReachable(_ completion: @escaping (Bool) -> Void) {
        guard let baseString = Settings.serverURL, let url = URL(string: baseString) else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        var req = URLRequest(url: url,
                             cachePolicy: .reloadIgnoringLocalCacheData,
                             timeoutInterval: 6)
        req.httpMethod = "HEAD"
        if let secret = Settings.authSecret {
            req.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: req) { _, response, _ in
            DispatchQueue.main.async {
                completion(response != nil)
            }
        }.resume()
    }
}
