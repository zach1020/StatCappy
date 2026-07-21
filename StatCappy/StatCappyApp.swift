import SwiftUI

@main
struct StatCappyApp: App {
    @StateObject private var monitor = SystemMonitor()
    @AppStorage(ThemeStore.key, store: ThemeStore.defaults) private var themeRaw = StatCappyTheme.liquidGlass.rawValue

    private var theme: StatCappyTheme { StatCappyTheme(rawValue: themeRaw) ?? .liquidGlass }

    var body: some Scene {
        MenuBarExtra {
            MenuDashboard(monitor: monitor, theme: theme)
        } label: {
            HStack(spacing: 3) {
                CapybaraFace(size: 17, mood: .cozy)
                Text(monitor.snapshot.temperatureCelsius.map { Formatters.temperature($0) } ?? monitor.snapshot.thermalState)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(monitor: monitor, themeRaw: $themeRaw)
        }
    }
}
