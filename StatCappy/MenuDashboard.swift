import SwiftUI
import AppKit

struct MenuDashboard: View {
    @ObservedObject var monitor: SystemMonitor
    let theme: StatCappyTheme
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(spacing: 8) {
                temperatureCard
                HStack(spacing: 8) {
                    MetricCard(title: "CPU", value: Formatters.percent(monitor.snapshot.cpuUsage), progress: monitor.snapshot.cpuUsage, color: .cyan, icon: "cpu", theme: theme)
                    MetricCard(title: "Memory", value: Formatters.percent(monitor.snapshot.memoryUsage), progress: monitor.snapshot.memoryUsage, color: .purple, icon: "memorychip", theme: theme)
                }
                HStack(spacing: 8) {
                    MetricCard(title: "Disk", value: Formatters.percent(monitor.snapshot.diskUsage), progress: monitor.snapshot.diskUsage, color: .orange, icon: "internaldrive", theme: theme)
                    batteryCard
                }
                networkCard
            }
            .padding(12)
            Divider()
            footer
        }
        .frame(width: 360, height: 462)
        .background(background)
        .background(WindowTransparencyHost(enabled: theme == .liquidGlass))
        .foregroundStyle(theme == .kawaii ? KawaiiTheme.ink : Color.primary)
        .tint(theme == .kawaii ? KawaiiTheme.pink : .cyan)
        .preferredColorScheme(theme == .liquidGlass ? .dark : .light)
    }

    private var header: some View {
        HStack {
            if theme == .kawaii {
                CapybaraFace(size: 34)
            } else {
                Image(systemName: "waveform.path.ecg.rectangle.fill")
                    .font(.title2).foregroundStyle(.cyan)
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("StatCappy").font(.headline)
                    if theme == .kawaii { Text("♡").foregroundStyle(KawaiiTheme.pink) }
                }
                if theme == .kawaii {
                    Text("Mac health buddy · マックのおとも")
                        .font(.caption2.weight(.medium)).foregroundStyle(KawaiiTheme.pink)
                } else {
                    Text("SYSTEM OVERVIEW").font(.caption2.weight(.semibold)).tracking(1.1).foregroundStyle(.cyan)
                }
                Text("Updated \(monitor.snapshot.updatedAt, style: .relative)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button { monitor.refresh() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain).help("Refresh now")
        }.padding(.horizontal, 12).padding(.vertical, 9)
    }

    private var temperatureCard: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                Circle().fill(theme == .kawaii ? KawaiiTheme.softPink : Color.cyan.opacity(0.10)).frame(width: 58, height: 58)
                if theme == .kawaii {
                    CapybaraFace(size: 48, mood: .cozy)
                } else {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 26, weight: .light)).foregroundStyle(.cyan)
                }
                if theme == .kawaii {
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(temperatureColor)
                    .padding(4)
                    .background(KawaiiTheme.cream, in: Circle())
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(theme == .kawaii ? "Temperature · 温度" : "DIE TEMPERATURE")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                if let temperature = monitor.snapshot.temperatureCelsius {
                    Text(Formatters.temperature(temperature, decimals: 1)).font(.system(size: 25, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text("Sensor average · \(monitor.snapshot.thermalState)").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text(monitor.snapshot.thermalState).font(.title2.bold())
                    Text("Raw sensor unavailable on this Mac").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(10).frame(height: 82).themedCard(theme)
    }

    private var temperatureColor: Color {
        guard let value = monitor.snapshot.temperatureCelsius else { return monitor.snapshot.thermalState == "Nominal" ? .green : .orange }
        return value >= 90 ? .red : value >= 70 ? .orange : .green
    }

    private var batteryCard: some View {
        MetricCard(title: "Battery",
                   value: monitor.snapshot.batteryPercent.map(Formatters.percent) ?? "—",
                   progress: monitor.snapshot.batteryPercent ?? 0,
                   color: monitor.snapshot.isCharging ? .green : .mint,
                   icon: monitor.snapshot.isCharging ? "battery.100percent.bolt" : "battery.75percent",
                   theme: theme)
    }

    private var networkCard: some View {
        HStack {
            Label("Network", systemImage: "arrow.up.arrow.down.circle.fill").foregroundStyle(.blue)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("↓ \(Formatters.speed(monitor.snapshot.networkDownBytesPerSecond))")
                Text("↑ \(Formatters.speed(monitor.snapshot.networkUpBytesPerSecond))")
            }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 11).padding(.vertical, 8).themedCard(theme)
    }

    private var footer: some View {
        HStack {
            Text(theme == .kawaii ? "Up \(Formatters.uptime(monitor.snapshot.uptime)) · 元気です" : "UPTIME \(Formatters.uptime(monitor.snapshot.uptime))")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Settings…") { openSettings() }.buttonStyle(.plain)
            Divider().frame(height: 14)
            Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.plain)
        }.padding(.horizontal, 12).padding(.vertical, 9)
    }

    @ViewBuilder private var background: some View {
        if theme == .kawaii {
            KawaiiTheme.cream
        } else {
            Color.clear
        }
    }
}

private struct WindowTransparencyHost: NSViewRepresentable {
    let enabled: Bool

    func makeNSView(context: Context) -> ClearHostView {
        let view = ClearHostView()
        view.enabled = enabled
        return view
    }

    func updateNSView(_ nsView: ClearHostView, context: Context) {
        nsView.enabled = enabled
        nsView.applyAppearance()
    }
}

private final class ClearHostView: NSView {
    var enabled = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyAppearance()
    }

    func applyAppearance() {
        guard let window else { return }
        window.isOpaque = !enabled
        window.backgroundColor = enabled ? .clear : NSColor(KawaiiTheme.cream)
        window.hasShadow = true
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let progress: Double
    let color: Color
    let icon: String
    let theme: StatCappyTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Label(title, systemImage: icon).font(.caption2).foregroundStyle(.secondary); Spacer() }
            Text(value).font(.headline.bold()).monospacedDigit()
            ProgressView(value: min(1, max(0, progress))).tint(color)
        }
        .padding(9).frame(maxWidth: .infinity, minHeight: 67, alignment: .leading)
        .themedCard(theme)
    }
}
