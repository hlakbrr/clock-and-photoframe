import UIKit
import WebKit

/// 相框模式：全屏 WKWebView 加载 ImmichFrame 服务端网页
/// （黑底、隐藏状态栏；加载失败显示报错页并 5 秒重试；自动切换由 ProbeEngine 驱动）
final class FrameViewController: UIViewController {

    private var webView: WKWebView!
    private var retryTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = self
        view.addSubview(webView)

        loadFrame()
    }

    func loadFrame() {
        retryTimer?.invalidate()
        retryTimer = nil

        guard let url = Settings.authenticatedURL() else { return }

        let request = URLRequest(url: url,
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 15)
        webView.load(request)
    }

    // MARK: - 错误处理（对齐安卓 error_page.html + 5 秒重试）

    private func handleLoadFailure(code: Int, description: String) {
        let safeDescription = description
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        let html = """
        <!DOCTYPE html>
        <html lang="zh">
        <head><meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body { background-color: #121212; color: #fff; font-family: -apple-system, sans-serif;
                   padding: 20px; text-align: center; }
            h2 { color: #ff5555; }
            .details { margin-top: 20px; font-size: 14px; color: #bbb; }
        </style></head>
        <body>
            <h2>连不上服务器</h2>
            <p>无法加载相框页面。请检查 NAS 是否开机、ImmichFrame 服务端是否在运行。</p>
            <p>5 秒后自动重试…</p>
            <div class="details">
                <p><strong>错误代码：</strong>\(code)</p>
                <p><strong>说明：</strong>\(safeDescription)</p>
            </div>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)

        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.loadFrame()
        }
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
}

extension FrameViewController: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // 对齐安卓 WebViewClient：站外链接交给 Safari 打开
        if navigationAction.navigationType == .linkActivated,
           let targetURL = navigationAction.request.url,
           let baseString = Settings.serverURL,
           let base = URL(string: baseString),
           let targetHost = targetURL.host,
           targetHost != base.host {
            UIApplication.shared.open(targetURL)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        handleLoadFailure(code: nsError.code, description: nsError.localizedDescription)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        let nsError = error as NSError
        handleLoadFailure(code: nsError.code, description: nsError.localizedDescription)
    }
}
