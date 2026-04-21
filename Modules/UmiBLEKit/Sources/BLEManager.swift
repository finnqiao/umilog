import Foundation
import CoreBluetooth
import Observation

@Observable
public final class BLEManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    public private(set) var state: CBManagerState = .unknown
    public private(set) var discoveredDevices: [BLEDiveComputer] = []
    public private(set) var connectedDevice: BLEDiveComputer?
    public private(set) var syncProgress: SyncProgress?
    public private(set) var pairedDevices: [PairedDevice] = []
    public private(set) var isScanning = false
    public private(set) var lastError: String?

    public static let knownServiceUUIDs = DiveComputerScanner.knownServiceUUIDs

    private let scanner = DiveComputerScanner()
    private let pairingManager: PairingManager
    private let shearwaterProtocol = ShearwaterProtocol()
    private let genericProtocol = GenericBLEDiveComputer()

    private var central: CBCentralManager!
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var connection: DiveComputerConnection?

    public override convenience init() {
        self.init(pairingManager: PairingManager())
    }

    public init(pairingManager: PairingManager) {
        self.pairingManager = pairingManager
        self.pairedDevices = pairingManager.loadPairedDevices()
        super.init()
        self.central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
    }

    public func refreshPairedDevices() {
        pairedDevices = pairingManager.loadPairedDevices()
    }

    public func startScanning() {
        guard state == .poweredOn else {
            lastError = "Bluetooth is not powered on."
            return
        }
        lastError = nil
        discoveredDevices.removeAll()
        discoveredPeripherals.removeAll()
        isScanning = true
        central.scanForPeripherals(
            withServices: Self.knownServiceUUIDs,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    public func stopScanning() {
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
    }

    public func connect(to device: BLEDiveComputer) {
        guard state == .poweredOn else {
            lastError = "Bluetooth is not powered on."
            return
        }
        guard let peripheral = discoveredPeripherals[device.id] else {
            lastError = "Device is no longer in range."
            return
        }
        lastError = nil
        connection = DiveComputerConnection(central: central, peripheral: peripheral)
        connection?.connect()
    }

    public func disconnect() {
        connection?.disconnect()
    }

    public func pair(device: BLEDiveComputer, serialNumber: String? = nil) {
        let paired = PairedDevice(
            id: device.id,
            name: device.name,
            brand: device.brand,
            serialNumber: serialNumber
        )
        pairingManager.upsert(paired)
        refreshPairedDevices()
        refreshDiscoveredPairingFlags()
    }

    public func forget(device: BLEDiveComputer) {
        pairingManager.remove(id: device.id)
        refreshPairedDevices()
        if connectedDevice?.id == device.id {
            disconnect()
        }
        refreshDiscoveredPairingFlags()
    }

    public func syncLatestDives() async throws -> [RawDiveData] {
        guard let connection else {
            lastError = "No connected device."
            return []
        }
        let brand = connectedDevice?.brand ?? .unknown
        let protocolImpl = protocolFor(brand: brand)
        let lastSync = pairedDevices.first { $0.id == connection.peripheralID }?.lastSyncedAt

        syncProgress = SyncProgress(stage: "Loading dive headers", fractionCompleted: 0.1)
        _ = try await protocolImpl.requestDiveHeaders(from: connection)
        syncProgress = SyncProgress(stage: "Downloading dives", fractionCompleted: 0.45)
        let dives = try await protocolImpl.downloadAllNewDives(since: lastSync, from: connection)
        syncProgress = SyncProgress(stage: "Finalizing", fractionCompleted: 0.9)
        pairingManager.updateLastSynced(id: connection.peripheralID, at: Date())
        refreshPairedDevices()
        refreshDiscoveredPairingFlags()
        syncProgress = SyncProgress(stage: "Complete", fractionCompleted: 1.0)
        return dives
    }

    public func clearSyncProgress() {
        syncProgress = nil
    }

    // MARK: - CBCentralManagerDelegate

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state
        if state != .poweredOn {
            stopScanning()
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        discoveredPeripherals[peripheral.identifier] = peripheral
        let device = scanner.makeDevice(
            from: peripheral,
            advertisementData: advertisementData,
            rssi: RSSI,
            isPaired: pairingManager.isPaired(id: peripheral.identifier)
        )

        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index] = device
        } else {
            discoveredDevices.append(device)
        }
        discoveredDevices.sort { $0.rssi > $1.rssi }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let existing = discoveredDevices.first(where: { $0.id == peripheral.identifier }) else {
            return
        }
        connection?.markConnected(true)
        connectedDevice = existing
        stopScanning()
    }

    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        lastError = error?.localizedDescription ?? "Failed to connect."
        connection?.markConnected(false)
        if connectedDevice?.id == peripheral.identifier {
            connectedDevice = nil
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        if connectedDevice?.id == peripheral.identifier {
            connectedDevice = nil
        }
        connection?.markConnected(false)
        if let error {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    private func protocolFor(brand: DiveComputerBrand) -> DiveComputerProtocol {
        switch brand {
        case .shearwater:
            return shearwaterProtocol
        case .suunto, .garmin, .unknown:
            return genericProtocol
        }
    }

    private func refreshDiscoveredPairingFlags() {
        let pairedIDs = Set(pairedDevices.map(\.id))
        discoveredDevices = discoveredDevices.map { device in
            BLEDiveComputer(
                id: device.id,
                name: device.name,
                brand: device.brand,
                rssi: device.rssi,
                isPaired: pairedIDs.contains(device.id)
            )
        }
    }
}
