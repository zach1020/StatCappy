import Foundation
import Darwin
import IOKit.ps
import WidgetKit

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot.placeholder
    @Published var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
            restartTimer()
        }
    }

    private var timer: Timer?
    private var previousCPU: (used: UInt64, total: UInt64)?
    private var previousNetwork: (down: UInt64, up: UInt64, date: Date)?
    private var lastWidgetReload = Date.distantPast

    init() {
        let saved = UserDefaults.standard.double(forKey: "refreshInterval")
        refreshInterval = saved > 0 ? saved : 5
        refresh()
        restartTimer()
    }

    func refresh() {
        let cpu = cpuUsage()
        let memory = memoryInfo()
        let disk = diskInfo()
        let battery = batteryInfo()
        let network = networkSpeed()
        let temperature = SensorBridgeCPUAndAverageTemperature()

        snapshot = SystemSnapshot(
            cpuUsage: cpu,
            memoryUsage: memory.total > 0 ? Double(memory.used) / Double(memory.total) : 0,
            usedMemoryBytes: memory.used,
            totalMemoryBytes: memory.total,
            diskUsage: disk.total > 0 ? 1 - Double(disk.free) / Double(disk.total) : 0,
            freeDiskBytes: disk.free,
            temperatureCelsius: temperature.isFinite && temperature > 0 ? temperature : nil,
            thermalState: thermalStateName(ProcessInfo.processInfo.thermalState),
            batteryPercent: battery.percent,
            isCharging: battery.charging,
            networkDownBytesPerSecond: network.down,
            networkUpBytesPerSecond: network.up,
            uptime: ProcessInfo.processInfo.systemUptime,
            updatedAt: .now
        )
        SharedSnapshotStore.save(snapshot)
        // WidgetKit snapshots do not need menu-bar frequency. Throttling this is
        // the biggest energy saving while keeping the Desktop widget current.
        if Date().timeIntervalSince(lastWidgetReload) >= 15 {
            WidgetCenter.shared.reloadAllTimelines()
            lastWidgetReload = .now
        }
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func cpuUsage() -> Double {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return snapshot.cpuUsage }
        let ticks = withUnsafeBytes(of: info.cpu_ticks) { Array($0.bindMemory(to: UInt32.self)) }
        guard ticks.count >= 4 else { return snapshot.cpuUsage }
        let used = UInt64(ticks[0]) + UInt64(ticks[1]) + UInt64(ticks[3])
        let total = used + UInt64(ticks[2])
        defer { previousCPU = (used, total) }
        guard let old = previousCPU, total > old.total else { return snapshot.cpuUsage }
        return min(1, max(0, Double(used - old.used) / Double(total - old.total)))
    }

    private func memoryInfo() -> (used: UInt64, total: UInt64) {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var stats = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let total = ProcessInfo.processInfo.physicalMemory
        guard result == KERN_SUCCESS else { return (0, total) }
        let page = UInt64(getpagesize())
        let available = (UInt64(stats.free_count) + UInt64(stats.inactive_count)) * page
        return (total > available ? total - available : 0, total)
    }

    private func diskInfo() -> (free: UInt64, total: UInt64) {
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]) else { return (0, 0) }
        return (UInt64(max(0, values.volumeAvailableCapacityForImportantUsage ?? 0)), UInt64(max(0, values.volumeTotalCapacity ?? 0)))
    }

    private func batteryInfo() -> (percent: Double?, charging: Bool) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else { return (nil, false) }
        let current = (description[kIOPSCurrentCapacityKey] as? NSNumber)?.doubleValue
        let maximum = (description[kIOPSMaxCapacityKey] as? NSNumber)?.doubleValue
        let charging = (description[kIOPSIsChargingKey] as? Bool) ?? false
        return (current.flatMap { value in maximum.map { $0 > 0 ? value / $0 : 0 } }, charging)
    }

    private func networkSpeed() -> (down: Double, up: Double) {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return (0, 0) }
        defer { freeifaddrs(addresses) }
        var down: UInt64 = 0
        var up: UInt64 = 0
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            let item = current.pointee
            if item.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               (item.ifa_flags & UInt32(IFF_LOOPBACK)) == 0,
               let data = item.ifa_data?.assumingMemoryBound(to: if_data.self) {
                down += UInt64(data.pointee.ifi_ibytes)
                up += UInt64(data.pointee.ifi_obytes)
            }
            pointer = item.ifa_next
        }
        let now = Date()
        defer { previousNetwork = (down, up, now) }
        guard let old = previousNetwork else { return (0, 0) }
        let elapsed = max(0.1, now.timeIntervalSince(old.date))
        return (Double(down >= old.down ? down - old.down : 0) / elapsed,
                Double(up >= old.up ? up - old.up : 0) / elapsed)
    }

    private func thermalStateName(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "Nominal"
        case .fair: "Warm"
        case .serious: "Hot"
        case .critical: "Critical"
        @unknown default: "Unknown"
        }
    }
}
