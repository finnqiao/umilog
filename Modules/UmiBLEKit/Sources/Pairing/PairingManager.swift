import Foundation

public final class PairingManager {
    private let defaults: UserDefaults
    private let storageKey = "app.umilog.ble.pairedDevices"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadPairedDevices() -> [PairedDevice] {
        guard let data = defaults.data(forKey: storageKey),
              let devices = try? decoder.decode([PairedDevice].self, from: data) else {
            return []
        }
        return devices
    }

    public func savePairedDevices(_ devices: [PairedDevice]) {
        guard let data = try? encoder.encode(devices) else { return }
        defaults.set(data, forKey: storageKey)
    }

    public func upsert(_ device: PairedDevice) {
        var devices = loadPairedDevices()
        if let existingIndex = devices.firstIndex(where: { $0.id == device.id }) {
            devices[existingIndex] = device
        } else {
            devices.insert(device, at: 0)
        }
        savePairedDevices(devices)
    }

    public func remove(id: UUID) {
        var devices = loadPairedDevices()
        devices.removeAll { $0.id == id }
        savePairedDevices(devices)
    }

    public func updateLastSynced(id: UUID, at date: Date) {
        var devices = loadPairedDevices()
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
        devices[index] = devices[index].withLastSyncedAt(date)
        savePairedDevices(devices)
    }

    public func isPaired(id: UUID) -> Bool {
        loadPairedDevices().contains { $0.id == id }
    }
}
