import SwiftUI
import IOKit.ps

// MARK: - System Info

@Observable
class SystemInfoViewModel {
    var batteryLevel: Int = 0
    var isCharging = false
    var wifiName = ""
    var storageUsed = ""
    var storageFree = ""
    var storageProgress: Double = 0
    var memoryUsed = ""
    var uptime = ""
    var displayCount = 1

    func refresh() {
        loadBattery()
        loadWifi()
        loadStorage()
        loadMemory()
        loadUptime()
        displayCount = NSScreen.screens.count
    }

    private func loadBattery() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        guard let source = sources.first else { return }
        let info = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as NSDictionary
        batteryLevel = info[kIOPSCurrentCapacityKey] as? Int ?? 0
        let state = info[kIOPSPowerSourceStateKey] as? String ?? ""
        isCharging = state == kIOPSACPowerValue as String
    }

    private func loadWifi() {
        let process = Process()
        process.launchPath = "/usr/sbin/networksetup"
        process.arguments = ["-getairportnetwork", "en0"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if output.contains(": ") {
            wifiName = output.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        } else {
            wifiName = "Not connected"
        }
    }

    private func loadStorage() {
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/")
        let total = (attrs?[.systemSize] as? Int64) ?? 0
        let free = (attrs?[.systemFreeSize] as? Int64) ?? 0
        let used = total - free
        storageUsed = ByteCountFormatter.string(fromByteCount: used, countStyle: .file)
        storageFree = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
        storageProgress = total > 0 ? Double(used) / Double(total) : 0
    }

    private func loadMemory() {
        let process = Process()
        process.launchPath = "/usr/bin/vm_stat"
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        // Parse active + wired pages
        var activePages: Int64 = 0
        var wiredPages: Int64 = 0
        for line in output.components(separatedBy: "\n") {
            if line.contains("Pages active") {
                activePages = Int64(line.components(separatedBy: ":").last?.trimmingCharacters(in: CharacterSet.decimalDigits.inverted) ?? "0") ?? 0
            }
            if line.contains("Pages wired") {
                wiredPages = Int64(line.components(separatedBy: ":").last?.trimmingCharacters(in: CharacterSet.decimalDigits.inverted) ?? "0") ?? 0
            }
        }
        let usedGB = Double((activePages + wiredPages) * 16384) / 1_073_741_824
        memoryUsed = String(format: "%.1f GB", usedGB)
    }

    private func loadUptime() {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        if sysctl(&mib, 2, &boottime, &size, nil, 0) == 0 {
            let seconds = Int(Date().timeIntervalSince1970) - boottime.tv_sec
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            uptime = "\(hours)h \(minutes)m"
        }
    }
}

// MARK: - System Dashboard View

struct SystemDashboardView: View {
    @State private var vm = SystemInfoViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("System")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    Button(action: vm.refresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)

                // Battery
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\u{1F50B} BATTERY")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        Spacer()
                        Text(vm.isCharging ? "\u{26A1} Charging" : "")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }

                    HStack(spacing: 10) {
                        Text("\(vm.batteryLevel)%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(vm.batteryLevel > 20 ? Theme.Colors.textPrimary : .red)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6).fill(Theme.Colors.rosePale).frame(height: 14)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(vm.batteryLevel > 20 ? Color.green : Color.red)
                                    .frame(width: geo.size.width * (Double(vm.batteryLevel) / 100), height: 14)
                            }
                        }
                        .frame(height: 14)
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Info Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    SystemInfoCard(icon: "\u{1F4F6}", title: "WiFi", value: vm.wifiName)
                    SystemInfoCard(icon: "\u{1F5A5}", title: "Displays", value: "\(vm.displayCount)")
                    SystemInfoCard(icon: "\u{23F1}", title: "Uptime", value: vm.uptime)
                    SystemInfoCard(icon: "\u{1F9E0}", title: "RAM Used", value: vm.memoryUsed)
                }
                .padding(.horizontal, 14)

                // Storage
                VStack(alignment: .leading, spacing: 8) {
                    Text("\u{1F4BE} STORAGE")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    HStack {
                        Text(vm.storageUsed)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("used")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textSoft)
                        Spacer()
                        Text(vm.storageFree)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                        Text("free")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textSoft)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Theme.Colors.rosePale).frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(vm.storageProgress > 0.85 ? AnyShapeStyle(Color.red) : AnyShapeStyle(Theme.Gradients.rosePrimary))
                                .frame(width: geo.size.width * vm.storageProgress, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Quick Actions
                VStack(alignment: .leading, spacing: 8) {
                    Text("\u{26A1} QUICK CONTROLS")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    HStack(spacing: 8) {
                        SystemActionButton(icon: "moon.fill", label: "Sleep") {
                            let script = "tell application \"System Events\" to sleep"
                            var error: NSDictionary?
                            NSAppleScript(source: script)?.executeAndReturnError(&error)
                        }
                        SystemActionButton(icon: "trash", label: "Empty Bin") {
                            let script = "tell application \"Finder\" to empty the trash"
                            var error: NSDictionary?
                            NSAppleScript(source: script)?.executeAndReturnError(&error)
                        }
                        SystemActionButton(icon: "arrow.clockwise", label: "Restart") {
                            let script = "tell application \"System Events\" to restart"
                            var error: NSDictionary?
                            NSAppleScript(source: script)?.executeAndReturnError(&error)
                        }
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
        .task { vm.refresh() }
    }
}

// MARK: - System Info Card

struct SystemInfoCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(icon).font(.system(size: 18))
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(Theme.Colors.textSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color.white.opacity(0.6))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.glassBorder, lineWidth: 0.5))
    }
}

// MARK: - System Action Button

struct SystemActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.rosePrimary)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.Colors.textMedium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.6))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
