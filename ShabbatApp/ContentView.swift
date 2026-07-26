import SwiftUI
import WebKit
import WidgetKit
import UserNotifications

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

        // Over-the-air content: load a previously downloaded copy if present,
        // otherwise the bundled file. Then fetch the latest version from
        // GitHub in the background for next launch, so small changes (design
        // tweaks, new cities) reach users without an App Store update.
        let cached = Self.cachedContentURL()
        if FileManager.default.fileExists(atPath: cached.path) {
            webView.loadFileURL(cached, allowingReadAccessTo: cached.deletingLastPathComponent())
        } else if let url = Bundle.main.url(forResource: "shabbat", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        Self.fetchLatestContent()
        return webView
    }

    static func cachedContentURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("shabbat.html")
    }

    static func fetchLatestContent() {
        guard let url = URL(string: "https://raw.githubusercontent.com/az0512124155azz-sys/shabbat-for-ios/main/ShabbatApp/shabbat.html") else { return }
        URLSession.shared.dataTask(with: url) { data, response, _ in
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let data = data, data.count > 10000,
                  let body = String(data: data, encoding: .utf8),
                  body.contains("hdr-title"),
                  body.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("</html>")
            else { return }
            let cached = cachedContentURL()
            let existing = try? String(contentsOf: cached, encoding: .utf8)
            if existing != body {
                try? body.write(to: cached, atomically: true, encoding: .utf8)
            }
        }.resume()
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

        @objc private func appBecameActive() {
            injectState()
            NotificationScheduler.refresh()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectState()
            NotificationScheduler.refresh()
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
            .onAppear {
                NotificationScheduler.requestPermissions()
                NotificationScheduler.refresh()
            }
    }
}

// ── Notification Scheduler ────────────────────────────────────────────────────

class NotificationScheduler {
    static func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    static func enable(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    ShabbatCore.setNotifEnabled(true)
                    self.refresh()
                    completion(true)
                }
            } else {
                completion(false)
            }
        }
    }

    static func disable() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        ShabbatCore.setNotifEnabled(false)
    }

    static func refresh() {
        guard ShabbatCore.notifEnabled else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }

        let city = ShabbatCore.loadCity()
        let t = ShabbatCore.nextShabbat(city)

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let candleDate = Calendar.current.date(byAdding: .minute, value: -15, to: t.candle) ?? t.candle
        scheduleNotification(
            title: "כניסת שבת",
            body: "שבת קודמת בעוד 15 דקות",
            at: candleDate,
            identifier: "candle_\(Int(t.saturday.timeIntervalSince1970))"
        )

        let havdalahDate = Calendar.current.date(byAdding: .minute, value: -20, to: t.havdalah) ?? t.havdalah
        scheduleNotification(
            title: "סיום שבת",
            body: "סיום שבת בעוד 20 דקות",
            at: havdalahDate,
            identifier: "havdalah_\(Int(t.saturday.timeIntervalSince1970))"
        )
    }

    private static func scheduleNotification(title: String, body: String, at date: Date, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

        guard let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false) else {
            return
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification scheduling failed: \(error)")
            }
        }
    }
}
