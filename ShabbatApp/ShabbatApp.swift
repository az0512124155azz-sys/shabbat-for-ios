import SwiftUI
import UserNotifications

@main
struct ShabbatApp: App {
    
    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        // Dark status bar
        UINavigationBar.appearance().barTintColor = UIColor(red: 0.04, green: 0.06, blue: 0.1, alpha: 1)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(Color(red: 0.04, green: 0.06, blue: 0.1))
        }
    }
}
