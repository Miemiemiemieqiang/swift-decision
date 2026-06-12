import SwiftUI
import SwiftData

@main
struct SwiftDecisionApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: Decision.self)
    }
}
