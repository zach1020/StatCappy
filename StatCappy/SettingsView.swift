import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var monitor: SystemMonitor
    @Binding var themeRaw: String
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var errorMessage: String?
    @AppStorage("showDockIcon") private var showDockIcon = false

    var body: some View {
        Form {
            Section("General") {
                Picker("Appearance", selection: $themeRaw) {
                    Label("Liquid Glass", systemImage: "drop.halffull").tag(StatCappyTheme.liquidGlass.rawValue)
                    Label("Kawaii", systemImage: "heart.fill").tag(StatCappyTheme.kawaii.rawValue)
                }
                .onChange(of: themeRaw) { _, rawValue in
                    AppIconController.apply(theme: StatCappyTheme(rawValue: rawValue) ?? .liquidGlass)
                }
                Toggle("Launch StatCappy at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in updateLoginItem(enabled) }
                Toggle("Show StatCappy in the Dock", isOn: $showDockIcon)
                    .onChange(of: showDockIcon) { _, visible in
                        NSApp.setActivationPolicy(visible ? .regular : .accessory)
                    }
                Picker("Refresh every", selection: $monitor.refreshInterval) {
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds · Recommended").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds · Low energy").tag(30.0)
                }
            }
            Section("Temperature") {
                Text("StatCappy reads available AppleSMC sensors and averages valid CPU/SoC readings. If macOS does not expose them on your model, the menu displays the system thermal-pressure state instead.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("About") {
                LabeledContent("Created by", value: "Zach Bohl (Cappy)")
                Link(destination: URL(string: "https://github.com/zach1020")!) {
                    Label("github.com/zach1020", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: URL(string: "https://zachbohl.com")!) {
                    Label("zachbohl.com", systemImage: "globe")
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.caption) }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 430)
        .tint(themeRaw == StatCappyTheme.kawaii.rawValue ? KawaiiTheme.pink : .cyan)
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            errorMessage = error.localizedDescription
        }
    }
}
