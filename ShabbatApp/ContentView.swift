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

        if let url = Bundle.main.url(forResource: "shabbat", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.cancelPendingLocationRequest()
        uiView.stopLoading()
        uiView.navigationDelegate = nil
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "shabbat")
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, CLLocationManagerDelegate {
        private static let widgetKinds = [
            "ShabbatTimesWidget",
            "NetzWidget",
            "TzeitWidget",
            "SunTimesWidget",
            "ParashaWidget",
            "TefillinWidget",
            "ComboWidget"
        ]

        private static func reloadWidgets() {
            for kind in widgetKinds {
                WidgetCenter.shared.reloadTimelines(ofKind: kind)
            }
            Self.reloadWidgets()
        }
        weak var webView: WKWebView?
        private let geocoder = CLGeocoder()
        private var pendingLocationRequestID: Int?
        private lazy var locationManager: CLLocationManager = {
            let manager = CLLocationManager()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyBest
            return manager
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

        deinit {
            NotificationCenter.default.removeObserver(self)
            geocoder.cancelGeocode()
        }

        @objc private func appBecameActive() {
            injectState()
            NotificationScheduler.refresh()
            Self.reloadWidgets()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectState()
        }

        func injectState() {
            let tefillin = ShabbatCore.tefillinMap()
            let tefillinJSON = (try? JSONSerialization.data(withJSONObject: tefillin))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

            let city = ShabbatCore.loadCity()
            let cityObject: [String: Any] = [
                "n": city.name,
                "e": city.nameEn,
                "f": city.nameFr,
                "la": city.lat,
                "lo": city.lon,
                "tz": city.tz,
                "c": city.country,
                "gps": city.isGPS
            ]
            let cityJSON = Self.json(cityObject)

            let js = """
            window.nativeInit&&nativeInit({
              notif:\(ShabbatCore.notifEnabled),
              tef:\(tefillinJSON),
              language:\(Self.json(ShabbatCore.language)),
              city:\(cityJSON)
            })
            """
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
                message.name == "shabbat",
                let body = message.body as? [String: Any],
                let command = body["cmd"] as? String
            else {
                return
            }

            switch command {
            case "city":
                guard
                    let city = body["city"] as? [String: Any],
                    let lat = Self.double(city["la"]),
                    let lon = Self.double(city["lo"])
                else {
                    return
                }

                let previous = ShabbatCore.loadCity()
                let timeZone = city["tz"] as? String ?? "Asia/Jerusalem"
                let changed =
                    abs(previous.lat - lat) > 0.000001 ||
                    abs(previous.lon - lon) > 0.000001 ||
                    previous.tz != timeZone

                ShabbatCore.saveCity(
                    name: city["n"] as? String ?? "",
                    nameEn: city["e"] as? String ?? "",
                    nameFr: city["f"] as? String ?? "",
                    lat: lat,
                    lon: lon,
                    tz: timeZone,
                    country: city["c"] as? String ?? "",
                    isGPS: city["gps"] as? Bool ?? false
                )

                if changed {
                    ShabbatCore.clearAppSnapshot()
                    NotificationScheduler.disablePendingOnly()
                    Self.reloadWidgets()
                }

            case "tefillin":
                if let key = body["key"] as? String, let value = body["value"] as? Bool {
                    ShabbatCore.setTefillin(key, value)
                    Self.reloadWidgets()
                }

            case "enableNotif":
                NotificationScheduler.enable { [weak self] granted in
                    self?.webView?.evaluateJavaScript(
                        "window.nativeNotifResult&&nativeNotifResult(\(granted))",
                        completionHandler: nil
                    )
                }

            case "disableNotif":
                NotificationScheduler.disable()

            case "setLanguage", "language":
                if let language = body["language"] as? String,
                   ["he", "en", "fr"].contains(language) {
                    ShabbatCore.language = language
                    NotificationScheduler.refresh()
                    // The language value is stored in the shared App Group.
                    // Reload every widget kind after the value has been flushed
                    // so existing home-screen widgets switch HE/EN/FR immediately.
                    Self.reloadWidgets()
                }

            case "syncSnapshot":
                if let snapshot = body["snapshot"] as? [String: Any],
                   ShabbatCore.saveAppSnapshot(snapshot) {
                    NotificationScheduler.refresh()
                    Self.reloadWidgets()
                }

            case "locate":
                let requestID = Self.int(body["id"]) ?? 0
                beginLocationRequest(requestID: requestID)

            default:
                break
            }
        }

        func cancelPendingLocationRequest() {
            pendingLocationRequestID = nil
            geocoder.cancelGeocode()
            locationManager.stopUpdatingLocation()
        }

        private func beginLocationRequest(requestID: Int) {
            pendingLocationRequestID = requestID
            geocoder.cancelGeocode()

            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.requestLocation()
            default:
                reportLocation(nil, requestID: requestID)
            }
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            guard let requestID = pendingLocationRequestID else { return }

            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                reportLocation(nil, requestID: requestID)
            default:
                break
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let requestID = pendingLocationRequestID else { return }
            reportLocation(locations.last, requestID: requestID)
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            guard let requestID = pendingLocationRequestID else { return }
            reportLocation(nil, requestID: requestID)
        }

        private func reportLocation(_ location: CLLocation?, requestID: Int) {
            guard pendingLocationRequestID == requestID else { return }

            guard let location else {
                pendingLocationRequestID = nil
                sendLocation([NSNull(), NSNull(), false, NSNull(), NSNull(), NSNull(), requestID])
                return
            }

            geocoder.cancelGeocode()
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
                guard let self, self.pendingLocationRequestID == requestID else { return }

                let placemark = placemarks?.first
                let timeZone = placemark?.timeZone?.identifier ?? TimeZone.current.identifier
                let name =
                    placemark?.locality ??
                    placemark?.subAdministrativeArea ??
                    placemark?.administrativeArea ??
                    ""
                let country = placemark?.isoCountryCode ?? placemark?.country ?? ""

                self.pendingLocationRequestID = nil
                self.sendLocation([
                    location.coordinate.latitude,
                    location.coordinate.longitude,
                    true,
                    timeZone,
                    name,
                    country,
                    requestID
                ])
            }
        }

        private func sendLocation(_ values: [Any]) {
            guard
                let data = try? JSONSerialization.data(withJSONObject: values),
                let arguments = String(data: data, encoding: .utf8)
            else {
                return
            }

            let js = "window.nativeLocationResult&&nativeLocationResult.apply(null,\(arguments))"
            DispatchQueue.main.async { [weak self] in
                self?.webView?.evaluateJavaScript(js, completionHandler: nil)
            }
        }

        private static func json(_ value: Any) -> String {
            guard
                JSONSerialization.isValidJSONObject([value]),
                let data = try? JSONSerialization.data(withJSONObject: [value]),
                let array = String(data: data, encoding: .utf8)
            else {
                return "null"
            }
            return String(array.dropFirst().dropLast())
        }

        private static func double(_ value: Any?) -> Double? {
            if let value = value as? Double { return value }
            if let value = value as? NSNumber { return value.doubleValue }
            if let value = value as? String { return Double(value) }
            return nil
        }

        private static func int(_ value: Any?) -> Int? {
            if let value = value as? Int { return value }
            if let value = value as? NSNumber { return value.intValue }
            if let value = value as? String { return Int(value) }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor action: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = action.request.url, url.scheme == "mailto" {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
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
