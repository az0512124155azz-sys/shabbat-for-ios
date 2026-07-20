import SwiftUI

@main
struct ShabbatApp: App {

    init() {
        // Dark status bar. Notification permission is requested only when the
        // user taps the notification button in the app (see ContentView bridge).
        UINavigationBar.appearance().barTintColor = UIColor(red: 0.04, green: 0.06, blue: 0.1, alpha: 1)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(Color(red: 0.04, green: 0.06, blue: 0.1))
        }
    }
}
