import SwiftUI
import WebKit
import WidgetKit

struct WebViewContainer: UIViewRepresentable {

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.userContentController.add(context.coordinator, name: "shabbat")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.04, green: 0.06, blue: 0.1, alpha: 1)
        webView.scrollView.backgroundColor = UIColor(red: 0.04, green: 0.06, blue: 0.1, alpha: 1)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        if let url = Bundle.main.url(forResource: "shabbat", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?

        override init() {
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appBecameActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }

        deinit { NotificationCenter.default.removeObserver(self) }

        @objc private func appBecameActive() { injectState() }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectState()
        }

        /// Push native-side state (notification flag + tefillin map) into the page.
        func injectState() {
            let tef = ShabbatCore.tefillinMap()
            let tefJSON = (try? JSONSerialization.data(withJSONObject: tef))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            let js = "window.nativeInit&&nativeInit({notif:\(ShabbatCore.notifEnabled),tef:\(tefJSON)})"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "shabbat",
                  let body = message.body as? [String: Any],
                  let cmd = body["cmd"] as? String else { return }
            switch cmd {
            case "city":
                if let city = body["city"] as? [String: Any],
                   let la = city["la"] as? Double, let lo = city["lo"] as? Double {
                    ShabbatCore.saveCity(
                        name: city["n"] as? String ?? "",
                        lat: la, lon: lo,
                        tz: city["tz"] as? String ?? "Asia/Jerusalem"
                    )
                    NotificationScheduler.refresh()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            case "tefillin":
                if let key = body["key"] as? String, let v = body["value"] as? Bool {
                    ShabbatCore.setTefillin(key, v)
                    WidgetCenter.shared.reloadAllTimelines()
                }
            case "enableNotif":
                NotificationScheduler.enable { granted in
                    self.webView?.evaluateJavaScript(
                        "window.nativeNotifResult&&nativeNotifResult(\(granted))",
                        completionHandler: nil
                    )
                }
            case "disableNotif":
                NotificationScheduler.disable()
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = action.request.url, url.scheme == "mailto" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

struct ContentView: View {
    var body: some View {
        WebViewContainer()
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
    }
}
