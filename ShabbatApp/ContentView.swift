import SwiftUI
import WebKit
import WidgetKit
import CoreLocation

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
        // HEAD always follows the repository's default branch, so over-the-air
        // updates keep working even if that branch is renamed in GitHub.
        guard let url = URL(string: "https://raw.githubusercontent.com/az0512124155azz-sys/shabbat-for-ios/HEAD/ShabbatApp/shabbat.html") else { return }
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

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, CLLocationManagerDelegate {
        weak var webView: WKWebView?
        private let geocoder = CLGeocoder()
        private lazy var locationManager: CLLocationManager = {
            let m = CLLocationManager()
            m.delegate = self
            return m
        }()

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
            // Advance the rolling 8-week notification window on every foreground,
            // so reminders keep firing even if the app isn't opened for weeks.
            NotificationScheduler.refresh()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectState()
        }

        /// Push native-side state (notification flag + tefillin map) into the page.
        func injectState() {
            let tef = ShabbatCore.tefillinMap()
            let tefJSON = (try? JSONSerialization.data(withJSONObject: tef))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            let js = "window.nativeInit&&nativeInit({notif:\(ShabbatCore.notifEnabled),tef:\(tefJSON),language:\(Self.json(ShabbatCore.language))})"
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
                        nameEn: city["e"] as? String ?? "",
                        nameFr: city["f"] as? String ?? "",
                        lat: la, lon: lo,
                        tz: city["tz"] as? String ?? "Asia/Jerusalem",
                        country: city["c"] as? String ?? "",
                        isGPS: city["gps"] as? Bool ?? false
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
            case "language":
                if let language = body["language"] as? String, ["he", "en", "fr"].contains(language) {
                    ShabbatCore.language = language
                    NotificationScheduler.refresh()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            case "locate":
                let status = locationManager.authorizationStatus
                switch status {
                case .notDetermined:
                    locationManager.requestWhenInUseAuthorization()
                case .authorizedWhenInUse, .authorizedAlways:
                    locationManager.requestLocation()
                default:
                    reportLocation(nil)
                }
            default:
                break
            }
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                reportLocation(nil)
            default:
                break
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            reportLocation(locations.last)
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            reportLocation(nil)
        }

        private static func json(_ value: Any) -> String {
            guard JSONSerialization.isValidJSONObject([value]),
                  let data = try? JSONSerialization.data(withJSONObject: [value]),
                  let array = String(data: data, encoding: .utf8) else { return "null" }
            return String(array.dropFirst().dropLast())
        }

        private func sendLocation(_ values: [Any]) {
            guard let data = try? JSONSerialization.data(withJSONObject: values),
                  let arguments = String(data: data, encoding: .utf8) else { return }
            let js = "window.nativeLocationResult&&nativeLocationResult.apply(null,\(arguments))"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(js, completionHandler: nil)
            }
        }

        private func reportLocation(_ location: CLLocation?) {
            guard let location else {
                sendLocation([NSNull(), NSNull(), false])
                return
            }
            geocoder.cancelGeocode()
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
                let p = placemarks?.first
                let tz = p?.timeZone?.identifier ?? TimeZone.current.identifier
                let name = p?.locality ?? p?.subAdministrativeArea ?? p?.administrativeArea ?? ""
                let country = p?.isoCountryCode ?? p?.country ?? ""
                self?.sendLocation([location.coordinate.latitude, location.coordinate.longitude, true, tz, name, country])
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
