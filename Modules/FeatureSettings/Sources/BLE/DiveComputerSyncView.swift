import SwiftUI
import CoreBluetooth
import UmiBLEKit
import UmiDB
import UmiCoreKit

public struct DiveComputerSyncView: View {
    @State private var bleManager = BLEManager()
    @State private var isSyncing = false
    @State private var statusMessage: String?

    private let diveRepository = DiveRepository(database: AppDatabase.shared)
    private let siteRepository = SiteRepository(database: AppDatabase.shared)
    private let profileRepository = DiveProfileRepository(database: AppDatabase.shared)

    public init() {}

    public var body: some View {
        List {
            Section("Status") {
                HStack {
                    Text("Bluetooth")
                    Spacer()
                    Text(stateLabel(bleManager.state))
                        .foregroundStyle(bleManager.state == .poweredOn ? .green : .secondary)
                }

                if let progress = bleManager.syncProgress {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: progress.fractionCompleted)
                        Text(progress.stage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let error = bleManager.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Paired Devices") {
                if bleManager.pairedDevices.isEmpty {
                    Text("No paired dive computers yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bleManager.pairedDevices) { device in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(device.name, systemImage: device.brand.icon)
                                Spacer()
                                if bleManager.connectedDevice?.id == device.id {
                                    Text("Connected")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.green)
                                }
                            }
                            if let serial = device.serialNumber, !serial.isEmpty {
                                Text("S/N: \(serial)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(lastSyncLabel(for: device.lastSyncedAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            HStack {
                                if bleManager.connectedDevice?.id == device.id {
                                    Button("Sync Now") {
                                        runSync()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(isSyncing)
                                } else if let discovered = bleManager.discoveredDevices.first(where: { $0.id == device.id }) {
                                    Button("Connect") {
                                        bleManager.connect(to: discovered)
                                    }
                                    .buttonStyle(.bordered)
                                } else {
                                    Text("Not in range")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Button("Forget", role: .destructive) {
                                    bleManager.forget(
                                        device: BLEDiveComputer(
                                            id: device.id,
                                            name: device.name,
                                            brand: device.brand,
                                            rssi: -100,
                                            isPaired: true
                                        )
                                    )
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Discovered Devices") {
                if bleManager.discoveredDevices.isEmpty {
                    Text(bleManager.isScanning ? "Scanning…" : "Tap Scan to discover nearby devices.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bleManager.discoveredDevices) { device in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(device.name, systemImage: device.brand.icon)
                                Spacer()
                                Text("\(device.rssi) dBm")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                if device.isPaired {
                                    Text("Paired")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Button("Pair") {
                                        bleManager.pair(device: device)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                Button("Connect") {
                                    bleManager.connect(to: device)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Dive Computer")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if bleManager.isScanning {
                    Button("Stop") {
                        bleManager.stopScanning()
                    }
                } else {
                    Button("Scan") {
                        bleManager.startScanning()
                    }
                }
            }
        }
        .task {
            bleManager.refreshPairedDevices()
            if bleManager.state == .poweredOn {
                bleManager.startScanning()
            }
        }
        .onDisappear {
            bleManager.stopScanning()
        }
    }

    private func runSync() {
        guard !isSyncing else { return }
        isSyncing = true
        statusMessage = nil

        Task {
            do {
                let rawDives = try await bleManager.syncLatestDives()
                let result = try importSyncedDives(rawDives, from: bleManager.connectedDevice)
                await MainActor.run {
                    statusMessage = "Imported \(result.imported), skipped \(result.skipped) duplicates."
                    NotificationCenter.default.post(name: .diveLogUpdated, object: nil)
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Sync failed: \(error.localizedDescription)"
                }
            }

            await MainActor.run {
                bleManager.clearSyncProgress()
                isSyncing = false
            }
        }
    }

    private func importSyncedDives(
        _ rawDives: [RawDiveData],
        from device: BLEDiveComputer?
    ) throws -> (imported: Int, skipped: Int) {
        var imported = 0
        var skipped = 0

        for raw in rawDives {
            if try diveRepository.hasDuplicate(date: raw.date, maxDepth: raw.maxDepth) {
                skipped += 1
                continue
            }

            let matchedSiteId = try autoMatchSiteId(for: raw)
            let gasMixJson = try? String(data: JSONEncoder().encode(raw.gasMixes), encoding: .utf8)
            let bottomTime = max(1, Int(raw.duration / 60.0))
            let startPressure = Int(raw.startPressure ?? 200)
            let endPressure = Int(raw.endPressure ?? 50)

            let dive = DiveLog(
                siteId: matchedSiteId,
                pendingLatitude: matchedSiteId == nil ? raw.latitude : nil,
                pendingLongitude: matchedSiteId == nil ? raw.longitude : nil,
                date: raw.date,
                startTime: raw.date,
                endTime: raw.date.addingTimeInterval(raw.duration),
                maxDepth: raw.maxDepth,
                averageDepth: raw.avgDepth,
                bottomTime: bottomTime,
                startPressure: startPressure,
                endPressure: endPressure,
                temperature: raw.minTemperature,
                visibility: 15,
                current: .none,
                conditions: .good,
                notes: "Synced from \(device?.brand.displayName ?? "dive computer") \(raw.computerModel ?? "")".trimmingCharacters(in: .whitespaces),
                gasMixesJson: gasMixJson,
                computerDiveNumber: raw.diveNumber,
                surfaceInterval: raw.surfaceInterval.map { Int($0) },
                safetyStopPerformed: raw.safetyStopPerformed
            )
            try diveRepository.create(dive)

            if !raw.depthProfile.isEmpty {
                let profileSamples = raw.depthProfile.map {
                    DiveProfileSample(
                        time: $0.time,
                        depth: $0.depth,
                        temperature: $0.temperature,
                        pressure: $0.pressure
                    )
                }
                let sampleBlob = try DiveProfile.encodeSamples(profileSamples)
                let interval = estimatedInterval(from: raw.depthProfile)
                let source: DiveProfile.Source = {
                    switch device?.brand {
                    case .shearwater: return .shearwater
                    case .suunto: return .suunto
                    case .garmin: return .garmin
                    default: return .unknown
                    }
                }()

                let profile = DiveProfile(
                    diveId: dive.id,
                    samples: sampleBlob,
                    sampleIntervalSec: interval,
                    sampleCount: profileSamples.count,
                    source: source,
                    computerSerial: raw.computerSerial,
                    computerModel: raw.computerModel
                )
                try profileRepository.upsert(profile)
            }

            imported += 1
        }

        return (imported, skipped)
    }

    private func autoMatchSiteId(for rawDive: RawDiveData) throws -> String? {
        guard let latitude = rawDive.latitude,
              let longitude = rawDive.longitude else {
            return nil
        }

        let nearby = try siteRepository.fetchNearby(
            latitude: latitude,
            longitude: longitude,
            radiusKm: 2.0,
            limit: 1
        )
        return nearby.first?.id
    }

    private func estimatedInterval(from samples: [DepthSample]) -> Int? {
        guard samples.count >= 2 else { return nil }
        let sorted = samples.sorted { $0.time < $1.time }
        return Int(max(1, (sorted[1].time - sorted[0].time).rounded()))
    }

    private func stateLabel(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOn: return "On"
        case .poweredOff: return "Off"
        case .resetting: return "Resetting"
        case .unauthorized: return "Unauthorized"
        case .unsupported: return "Unsupported"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }

    private func lastSyncLabel(for date: Date?) -> String {
        guard let date else { return "Never synced" }
        return "Last sync \(date.formatted(.relative(presentation: .named)))"
    }
}
