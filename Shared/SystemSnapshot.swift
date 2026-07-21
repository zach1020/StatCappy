import Foundation

struct SystemSnapshot: Codable, Sendable {
    var cpuUsage: Double
    var memoryUsage: Double
    var usedMemoryBytes: UInt64
    var totalMemoryBytes: UInt64
    var diskUsage: Double
    var freeDiskBytes: UInt64
    var temperatureCelsius: Double?
    var thermalState: String
    var batteryPercent: Double?
    var isCharging: Bool
    var networkDownBytesPerSecond: Double
    var networkUpBytesPerSecond: Double
    var uptime: TimeInterval
    var updatedAt: Date

    static let placeholder = SystemSnapshot(
        cpuUsage: 0.27, memoryUsage: 0.58,
        usedMemoryBytes: 9_340_000_000, totalMemoryBytes: 16_000_000_000,
        diskUsage: 0.64, freeDiskBytes: 184_000_000_000,
        temperatureCelsius: 47, thermalState: "Nominal",
        batteryPercent: 0.82, isCharging: false,
        networkDownBytesPerSecond: 2_400_000, networkUpBytesPerSecond: 180_000,
        uptime: 302_400, updatedAt: .now
    )
}

enum SharedSnapshotStore {
    static let suiteName = "group.com.statcappy.app"
    static let snapshotKey = "latestSystemSnapshot"

    static func save(_ snapshot: SystemSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.set(data, forKey: snapshotKey)
        defaults?.synchronize()
    }

    static func load() -> SystemSnapshot? {
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.synchronize()
        guard let data = defaults?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(SystemSnapshot.self, from: data)
    }
}

enum StatCappyTheme: String, CaseIterable, Identifiable, Sendable {
    case liquidGlass
    case kawaii

    var id: String { rawValue }
    var title: String { self == .liquidGlass ? "Liquid Glass" : "Kawaii" }
}

enum ThemeStore {
    static let key = "selectedTheme"
    nonisolated(unsafe) static let defaults = UserDefaults(suiteName: SharedSnapshotStore.suiteName)!
}

enum Formatters {
    static func fahrenheit(_ celsius: Double) -> Double {
        celsius * 9 / 5 + 32
    }

    static func temperature(_ celsius: Double, decimals: Int = 0) -> String {
        let value = fahrenheit(celsius)
        return decimals == 0 ? "\(Int(value.rounded()))°F" : String(format: "%.1f°F", value)
    }

    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    static func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .memory)
    }

    static func speed(_ value: Double) -> String {
        "\(ByteCountFormatter.string(fromByteCount: Int64(max(0, value)), countStyle: .file))/s"
    }

    static func uptime(_ interval: TimeInterval) -> String {
        let days = Int(interval) / 86_400
        let hours = (Int(interval) % 86_400) / 3_600
        return days > 0 ? "\(days)d \(hours)h" : "\(hours)h \((Int(interval) % 3_600) / 60)m"
    }
}
