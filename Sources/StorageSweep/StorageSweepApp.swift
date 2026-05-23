import SwiftUI

@main
struct StorageSweepApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1050, minHeight: 680)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
