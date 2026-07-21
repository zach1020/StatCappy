import WidgetKit
import SwiftUI

struct StatEntry: TimelineEntry {
    let date: Date
    let snapshot: SystemSnapshot
    let theme: StatCappyTheme
}

struct StatProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatEntry {
        StatEntry(date: .now, snapshot: .placeholder, theme: .liquidGlass)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatEntry>) -> Void) {
        completion(Timeline(entries: [makeEntry()], policy: .after(Date().addingTimeInterval(15))))
    }

    private func makeEntry() -> StatEntry {
        ThemeStore.defaults.synchronize()
        let rawTheme = ThemeStore.defaults.string(forKey: ThemeStore.widgetKey)
        let theme = StatCappyTheme(rawValue: rawTheme ?? "") ?? .liquidGlass
        return StatEntry(date: .now, snapshot: SharedSnapshotStore.load() ?? .placeholder, theme: theme)
    }
}

struct StatCappyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatEntry
    private var theme: StatCappyTheme { entry.theme }

    var body: some View {
        Group {
            if family == .systemSmall { smallView } else { mediumView }
        }
        .padding(14)
        .foregroundStyle(theme == .kawaii ? KawaiiTheme.ink : Color.primary)
        .containerBackground(for: .widget) {
            if theme == .kawaii {
                KawaiiTheme.softPink
            } else {
                Color.clear
            }
        }
    }

    private var temperatureText: String {
        entry.snapshot.temperatureCelsius.map { Formatters.temperature($0) } ?? entry.snapshot.thermalState
    }

    private var accent: Color { theme == .kawaii ? KawaiiTheme.pink : .cyan }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if theme == .kawaii {
                    CapybaraFace(size: 24)
                } else {
                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .font(.title3).symbolRenderingMode(.hierarchical)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("STATCAPPY").font(.caption2.bold()).tracking(0.5)
                    Text(theme == .kawaii ? "マックのおとも" : "LIVE SYSTEMS")
                        .font(.system(size: 8, weight: .semibold)).foregroundStyle(accent)
                }
            }
            Spacer()
            Image(systemName: "thermometer.medium").font(.title3).foregroundStyle(accent)
            Text(temperatureText)
                .font(.system(size: 33, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.65).monospacedDigit()
            Text("CPU \(Formatters.percent(entry.snapshot.cpuUsage)) · RAM \(Formatters.percent(entry.snapshot.memoryUsage))")
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            freshness
        }
    }

    private var mediumView: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    if theme == .kawaii {
                        CapybaraFace(size: 30, mood: .cozy)
                    } else {
                        Image(systemName: "waveform.path.ecg.rectangle.fill")
                            .font(.title2).symbolRenderingMode(.hierarchical)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Temperature").font(.caption.weight(.semibold))
                        Text(theme == .kawaii ? "温度 · ぽかぽかチェック" : "DIE SENSOR AVERAGE")
                            .font(.system(size: 8, weight: .semibold)).foregroundStyle(accent)
                    }
                }
                Text(temperatureText)
                    .font(.system(size: 35, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7).monospacedDigit()
                Text(entry.snapshot.temperatureCelsius == nil ? "Thermal pressure" : entry.snapshot.thermalState)
                    .font(.caption2).foregroundStyle(.secondary)
                freshness
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            VStack(spacing: 9) {
                widgetRow("CPU", value: entry.snapshot.cpuUsage, color: .cyan)
                widgetRow("RAM", value: entry.snapshot.memoryUsage, color: .purple)
                widgetRow("Disk", value: entry.snapshot.diskUsage, color: .orange)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var freshness: some View {
        Text("Synced \(entry.snapshot.updatedAt, style: .relative)")
            .font(.system(size: 8)).foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func widgetRow(_ title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text(Formatters.percent(value)).monospacedDigit()
            }
            .font(.caption)
            ProgressView(value: value).tint(color)
        }
    }
}

struct StatCappyWidget: Widget {
    // A fresh kind avoids macOS restoring the incompatible AppIntent-backed
    // configuration shipped briefly in 1.2.
    let kind = "StatCappyWidgetV2"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatProvider()) {
            StatCappyWidgetView(entry: $0)
        }
        .configurationDisplayName("StatCappy")
        .description("Live Mac health in your independently selected StatCappy widget theme.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

@main
struct StatCappyWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatCappyWidget()
    }
}
