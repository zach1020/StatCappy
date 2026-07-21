import SwiftUI
import AppKit

@MainActor
enum AppIconController {
    static func apply(theme: StatCappyTheme) {
        let assetName = theme == .kawaii ? "KawaiiIcon" : "GlassIcon"
        if let image = NSImage(named: assetName) {
            NSApp.applicationIconImage = image
        }
    }
}

final class StatCappyAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
        let rawTheme = ThemeStore.defaults.string(forKey: ThemeStore.key)
        AppIconController.apply(theme: StatCappyTheme(rawValue: rawTheme ?? "") ?? .liquidGlass)
    }
}

@main
struct StatCappyApp: App {
    @NSApplicationDelegateAdaptor(StatCappyAppDelegate.self) private var appDelegate
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
