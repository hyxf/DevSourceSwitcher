import SwiftUI

@main
struct DevSourceSwitcherApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }

        WindowGroup(for: ConfigContent.self) { $content in
            if let item = content {
                ConfigContentView(item: item)
            }
        }
    }
}
