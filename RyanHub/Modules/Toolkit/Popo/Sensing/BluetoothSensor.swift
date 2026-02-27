import Foundation
import CoreBluetooth

// MARK: - Bluetooth Sensor

/// Scans for nearby Bluetooth peripherals.
/// Detects known devices (AirPods, Watch, car Bluetooth) for context.
final class BluetoothSensor: NSObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager?
    private var isRunning = false
    private var scanTimer: Timer?
    private var discoveredDevices: Set<String> = []

    /// Callback invoked when a new sensing event is captured.
    var onEvent: ((SensingEvent) -> Void)?

    // MARK: - Lifecycle

    /// Start Bluetooth scanning. Initializes the CBCentralManager which will
    /// trigger `centralManagerDidUpdateState` when ready.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: false
        ])
    }

    /// Stop Bluetooth scanning and clean up.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        centralManager?.stopScan()
        scanTimer?.invalidate()
        scanTimer = nil
        centralManager = nil
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startPeriodicScan()
        default:
            let event = SensingEvent(
                modality: .bluetooth,
                payload: [
                    "state": "unavailable",
                    "reason": "\(central.state.rawValue)"
                ]
            )
            onEvent?(event)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name ?? "Unknown"
        let id = peripheral.identifier.uuidString

        // Only report each device once per scan cycle
        guard !discoveredDevices.contains(id) else { return }
        discoveredDevices.insert(id)

        // Only report named devices (skip unnamed BLE beacons)
        guard peripheral.name != nil else { return }

        let event = SensingEvent(
            modality: .bluetooth,
            payload: [
                "device": name,
                "uuid": id,
                "rssi": "\(RSSI.intValue)"
            ]
        )
        onEvent?(event)
    }

    // MARK: - Periodic Scanning

    /// Set up a recurring scan: 10 seconds of scanning every 5 minutes.
    private func startPeriodicScan() {
        performScan()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.performScan()
        }
    }

    /// Run a single BLE scan burst for 10 seconds.
    private func performScan() {
        discoveredDevices.removeAll()
        centralManager?.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])

        // Stop scanning after 10 seconds to save power
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.centralManager?.stopScan()
        }
    }
}
