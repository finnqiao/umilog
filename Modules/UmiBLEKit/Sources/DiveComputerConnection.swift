import Foundation
import CoreBluetooth

public final class DiveComputerConnection {
    private weak var central: CBCentralManager?
    fileprivate let peripheral: CBPeripheral

    public let peripheralID: UUID
    public let deviceName: String
    public fileprivate(set) var isConnected: Bool

    init(
        central: CBCentralManager,
        peripheral: CBPeripheral,
        isConnected: Bool = false
    ) {
        self.central = central
        self.peripheral = peripheral
        self.peripheralID = peripheral.identifier
        self.deviceName = peripheral.name ?? "Unknown Device"
        self.isConnected = isConnected
    }

    public func connect() {
        central?.connect(peripheral)
    }

    public func disconnect() {
        central?.cancelPeripheralConnection(peripheral)
    }

    func markConnected(_ connected: Bool) {
        isConnected = connected
    }
}
