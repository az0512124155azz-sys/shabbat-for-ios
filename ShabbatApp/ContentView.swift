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

        // App Store-safe OTA model:
        // the executable HTML/JavaScript stays bundled with the app.
        // Only validated JSON data/config is downloaded from the shared OTA
        // production/staging manifest.
        if let url = Bundle.main.url(forResource: "shabbat", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        Self.fetchLatestRemoteConfig { config in
            guard let config else { return }
            DispatchQueue.main.async {
                context.coordinator.applyRemoteConfig(config)
            }
        }

        return webView
    }

    private static var otaManifestURL: URL? {
#if DEBUG
        return URL(string:
            "https://raw.githubusercontent.com/az0512124155azz-sys/" +
            "shabbat-for-android/main/ota/staging/manifest.json"
        )
#else
        return URL(string:
            "https://raw.githubusercontent.com/az0512124155azz-sys/" +
            "shabbat-for-android/main/ota/manifest.json"
        )
#endif
    }

    private static func cachedRemoteConfigURL() -> URL {
        let dir = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir.appendingPathComponent("ota-content.json")
    }

    static func cachedRemoteConfig() -> [String: Any]? {
        let url = cachedRemoteConfigURL()
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data),
              let config = object as? [String: Any]
        else {
            return nil
        }
        return config
    }

    private static func currentBuildNumber() -> Int {
        let value = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String
        return Int(value ?? "") ?? 0
    }

    static func fetchLatestRemoteConfig(
        completion: @escaping ([String: Any]?) -> Void
    ) {
        guard let manifestURL = otaManifestURL else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: manifestURL) { manifestData, response, _ in
            guard
                let http = response as? HTTPURLResponse,
                http.statusCode == 200,
                let manifestData,
                let manifestObject = try? JSONSerialization.jsonObject(with: manifestData),
                let manifest = manifestObject as? [String: Any],
                (manifest["schema"] as? Int) == 1,
                let revision = manifest["revision"] as? String,
                !revision.isEmpty,
                let ios = manifest["ios"] as? [String: Any],
                let contentURLText = ios["contentUrl"] as? String,
                let contentURL = URL(string: contentURLText)
            else {
                completion(nil)
                return
            }

            let minBuild = ios["minBuildNumber"] as? Int ?? 1
            guard currentBuildNumber() >= minBuild else {
                completion(nil)
                return
            }

            URLSession.shared.dataTask(with: contentURL) { data, response, _ in
                guard
                    let http = response as? HTTPURLResponse,
                    http.statusCode == 200,
                    let data,
                    let object = try? JSONSerialization.jsonObject(with: data),
                    let config = object as? [String: Any],
                    (config["schema"] as? Int) == 1,
                    (config["revision"] as? String) == revision,
                    config["labels"] is [String: Any]
                else {
                    completion(nil)
                    return
                }

                try? data.write(
                    to: cachedRemoteConfigURL(),
                    options: .atomic
                )
                completion(config)
            }.resume()
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

            if let cached = WebViewContainer.cachedRemoteConfig() {
                applyRemoteConfig(cached)
            }

            WebViewContainer.fetchLatestRemoteConfig { [weak self] config in
                guard let self, let config else { return }
                DispatchQueue.main.async {
                    self.applyRemoteConfig(config)
                }
            }

            // Advance the rolling 8-week notification window on every foreground,
            // so reminders keep firing even if the app isn't opened for weeks.
            NotificationScheduler.refresh()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectState()
            if let cached = WebViewContainer.cachedRemoteConfig() {
                applyRemoteConfig(cached)
            }
        }

        func applyRemoteConfig(_ config: [String: Any]) {
            guard
                JSONSerialization.isValidJSONObject(config),
                let data = try? JSONSerialization.data(withJSONObject: config),
                let json = String(data: data, encoding: .utf8)
            else {
                return
            }

            webView?.evaluateJavaScript(
                "window.applyRemoteConfig&&window.applyRemoteConfig(\(json))",
                completionHandler: nil
            )
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
