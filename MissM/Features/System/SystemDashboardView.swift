import SwiftUI
import IOKit.ps
import SystemConfiguration

// MARK: - System Dashboard View (Phase 7)
// Battery + WiFi + storage + system controls

struct SystemDashboardView: View {
    @State private var batteryLevel: Int = 0
    @State private var isCharging = false
    @State private var storageUsed: String = ""
    @State private var storageFree: String = ""
    @State private var storagePercent: Double = 0
    @State private var isWifiConnected = false
    @State private var wifiName: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack(spacing: 0) {
                    Text("System ")
                        .font(.custom("PlayfairDisplay-Italic", size: 20))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("Dashboard")
                        .font(.custom("PlayfairDisplay-Italic", size: 20))
                        .foregroundColor(Theme.Colors.rosePrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

                // Battery card
                SystemCard(icon: isCharging ? "🔌" : "🔋", title: "Battery") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(batteryLevel)%")
                                .font(.custom("CormorantGaramond-SemiBold", size: 28))
                                .foregroundColor(batteryColor)
                            Spacer()
                            Text(isCharging ? "Charging" : "On Battery")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(isCharging ? .green : Theme.Colors.textSoft)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(isCharging ? Color.green.opacity(0.1) : Theme.Colors.rosePale)
                                .cornerRadius(8)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.Colors.rosePale)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(batteryColor)
                                    .frame(width: geo.size.width * Double(batteryLevel) / 100.0)
                            }
                        }
                        .frame(height: 6)
                    }
                }

                // Storage card
                SystemCard(icon: "💾", title: "Storage") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(storageUsed)
                                .font(.custom("CormorantGaramond-SemiBold", size: 22))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("used")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textSoft)
                            Spacer()
                            Text("\(storageFree) free")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.Colors.textSoft)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.Colors.rosePale)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [Theme.Colors.rosePrimary, Theme.Colors.roseDeep], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * storagePercent)
                            }
                        }
                        .frame(height: 6)
                    }
                }

                // WiFi card
                SystemCard(icon: "📶", title: "Network") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isWifiConnected ? wifiName : "Not connected")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text(isWifiConnected ? "Connected" : "No WiFi")
                                .font(.system(size: 10))
                                .foregroundColor(isWifiConnected ? .green : .orange)
                        }
                        Spacer()
                        Circle()
                            .fill(isWifiConnected ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                            .shadow(color: isWifiConnected ? Color.green.opacity(0.6) : Color.orange.opacity(0.6), radius: 4)
                    }
                }

                // Quick Actions
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("QUICK ACTIONS")
                            .font(.custom("CormorantGaramond-SemiBold", size: 10))
                            .tracking(2.5)
                            .foregroundColor(Theme.Colors.rosePrimary)
                        Rectangle()
                            .fill(Theme.Colors.rosePrimary.opacity(0.14))
                            .frame(height: 1)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        SystemQuickAction(icon: "🌙", label: "Do Not Disturb") {}
                        SystemQuickAction(icon: "🔇", label: "Mute Sound") {}
                        SystemQuickAction(icon: "☀️", label: "Brightness") {}
                        SystemQuickAction(icon: "🗑", label: "Empty Trash") {
                            let script = NSAppleScript(source: "tell application \"Finder\" to empty the trash")
                            var error: NSDictionary?
                            script?.executeAndReturnError(&error)
                        }
                    }
                }
                .padding(14)
                .glassCard(padding: 0)
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
        }
        .onAppear { refreshAll() }
    }

    private var batteryColor: Color {
        if batteryLevel > 50 { return .green }
        if batteryLevel > 20 { return .orange }
        return .red
    }

    // MARK: - Data Fetching

    private func refreshAll() {
        fetchBattery()
        fetchStorage()
        fetchWifi()
    }

    private func fetchBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any] else {
            return
        }

        batteryLevel = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let state = desc[kIOPSPowerSourceStateKey] as? String ?? ""
        isCharging = state == kIOPSACPowerValue
    }

    private func fetchStorage() {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let totalBytes = attrs[.systemSize] as? Int64 ?? 0
            let freeBytes = attrs[.systemFreeSize] as? Int64 ?? 0
            let usedBytes = totalBytes - freeBytes

            let formatter = ByteCountFormatter()
            formatter.countStyle = .file

            storageUsed = formatter.string(fromByteCount: usedBytes)
            storageFree = formatter.string(fromByteCount: freeBytes)
            storagePercent = totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0
        } catch {}
    }

    private func fetchWifi() {
        // Check reachability
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)

        guard let reachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptr in
                SCNetworkReachabilityCreateWithAddress(nil, ptr)
            }
        }) else {
            isWifiConnected = false
            return
        }

        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reachability, &flags)
        isWifiConnected = flags.contains(.reachable) && !flags.contains(.connectionRequired)
        wifiName = isWifiConnected ? "WiFi" : ""
    }
}

// MARK: - System Card
struct SystemCard<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            content()
        }
        .padding(14)
        .glassCard(padding: 0)
        .padding(.horizontal, 16)
    }
}

// MARK: - System Quick Action
struct SystemQuickAction: View {
    let icon: String
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(icon)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isHovered ? Color.white : Color.white.opacity(0.7))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.glassBorder, lineWidth: 1))
            .offset(y: isHovered ? -1 : 0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
