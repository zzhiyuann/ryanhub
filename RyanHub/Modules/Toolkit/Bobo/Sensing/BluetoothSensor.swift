import Foundation
import CoreBluetooth

// MARK: - Bluetooth Sensor

/// Scans for nearby Bluetooth peripherals.
/// Detects known devices (AirPods, Watch, car Bluetooth) for context.
/// Emits ONE aggregated event per scan cycle instead of individual device events.
final class BluetoothSensor: NSObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager?
    private var isRunning = false
    private var scanTimer: Timer?

    /// All device UUIDs discovered in the current scan cycle.
    private var discoveredDeviceIDs: Set<String> = []

    /// Named devices discovered in the current scan cycle.
    private var discoveredNamedDevices: [String] = []

    /// Whether a quick (background) scan is in progress.
    private var isQuickScan = false

    /// Duration for the current scan (normal=10s, quick=5s).
    private var currentScanDuration: TimeInterval = 10

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

    // MARK: - Background Quick Scan

    /// Perform a shorter scan suitable for background wake-ups.
    /// Emits one aggregated event after the scan completes.
    func quickScan(duration: TimeInterval = 5) {
        guard centralManager?.state == .poweredOn else {
            // If BT manager isn't ready yet, initialize it — the scan will
            // start once centralManagerDidUpdateState fires with .poweredOn.
            if centralManager == nil {
                isQuickScan = true
                currentScanDuration = duration
                centralManager = CBCentralManager(delegate: self, queue: nil, options: [
                    CBCentralManagerOptionShowPowerAlertKey: false
                ])
            }
            return
        }

        isQuickScan = true
        currentScanDuration = duration
        performScan()
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if isQuickScan {
                // Triggered by quickScan() — do a single short scan
                performScan()
            } else {
                startPeriodicScan()
            }
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
        let id = peripheral.identifier.uuidString

        // Track every unique device (including unnamed)
        discoveredDeviceIDs.insert(id)

        // Track named devices separately for the aggregated report
        if let name = peripheral.name, !discoveredNamedDevices.contains(name) {
            discoveredNamedDevices.append(name)
        }
    }

    // MARK: - Periodic Scanning

    /// Set up a recurring scan: 10 seconds of scanning every 5 minutes.
    private func startPeriodicScan() {
        currentScanDuration = 10
        performScan()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.currentScanDuration = 10
            self?.performScan()
        }
    }

    /// Run a single BLE scan burst. At the end, emit ONE aggregated event
    /// with device counts and named device list.
    private func performScan() {
        discoveredDeviceIDs.removeAll()
        discoveredNamedDevices.removeAll()

        centralManager?.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])

        let duration = currentScanDuration

        // Stop scanning after the configured duration and emit aggregated result
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else { return }
            self.centralManager?.stopScan()

            let totalCount = self.discoveredDeviceIDs.count
            let namedDevices = self.discoveredNamedDevices
            let namedCount = namedDevices.count

            // Only emit an event if we found at least one device
            guard totalCount > 0 else {
                // Reset quick scan flag
                self.isQuickScan = false
                return
            }

            let event = SensingEvent(
                modality: .bluetooth,
                payload: [
                    "deviceCount": "\(totalCount)",
                    "namedCount": "\(namedCount)",
                    "devices": namedDevices.joined(separator: ", "),
                    "scanDuration": String(format: "%.0f", duration)
                ]
            )
            self.onEvent?(event)

            // Reset quick scan flag — don't start periodic if this was background
            if self.isQuickScan {
                self.isQuickScan = false
            }
        }
    }
}
