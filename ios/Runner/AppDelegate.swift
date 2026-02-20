import Flutter
import UIKit
import CoreBluetooth
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "com.liftco.ibeacon"
  private var peripheralManager: CBPeripheralManager?
  private var pendingStart: (uuid: UUID, major: UInt16, minor: UInt16, txPower: Int)?
  private var isAdvertising: Bool = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        switch call.method {
        case "getSupport":
          result(self.getSupport())
        case "start":
          guard
            let args = call.arguments as? [String: Any],
            let uuidStr = args["uuid"] as? String,
            let uuid = UUID(uuidString: uuidStr),
            let major = args["major"] as? Int,
            let minor = args["minor"] as? Int
          else {
            result(FlutterError(code: "bad_args", message: "uuid/major/minor required", details: nil))
            return
          }

          let txPower = (args["tx_power"] as? Int) ?? -59
          self.startAdvertising(uuid: uuid, major: major, minor: minor, txPower: txPower)
          result(nil)

        case "stop":
          self.stopAdvertising()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func ensureManager() {
    if peripheralManager == nil {
      peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
  }

  private func getSupport() -> [String: Any] {
    ensureManager()
    let state = peripheralManager?.state ?? .unknown

    let bluetoothOn = state == .poweredOn
    let supported = state != .unsupported
    let advertisingAvailable = CBPeripheralManager.isAdvertisingSupported()
    let details: String?

    switch state {
    case .poweredOn:
      details = nil
    case .poweredOff:
      details = "Bluetooth is off"
    case .unauthorized:
      details = "Bluetooth unauthorized"
    case .unsupported:
      details = "Bluetooth unsupported"
    case .resetting:
      details = "Bluetooth resetting"
    case .unknown:
      details = "Bluetooth state unknown"
    @unknown default:
      details = "Bluetooth state unknown"
    }

    return [
      "platform": "ios",
      "is_supported": supported,
      "bluetooth_on": bluetoothOn,
      "advertising_available": advertisingAvailable,
      "details": details as Any,
    ]
  }

  private func startAdvertising(uuid: UUID, major: Int, minor: Int, txPower: Int) {
    ensureManager()
    pendingStart = (
      uuid: uuid,
      major: UInt16(clamping: major),
      minor: UInt16(clamping: minor),
      txPower: txPower
    )

    // If Bluetooth is already on, start immediately.
    if peripheralManager?.state == .poweredOn {
      startPendingIfPossible()
    }
  }

  private func startPendingIfPossible() {
    guard let mgr = peripheralManager else { return }
    guard mgr.state == .poweredOn else { return }
    guard let pending = pendingStart else { return }

    stopAdvertising()

    let region = CLBeaconRegion(
      uuid: pending.uuid,
      major: pending.major,
      minor: pending.minor,
      identifier: "com.liftco.attendance"
    )

    let power = NSNumber(value: pending.txPower)
    let data = region.peripheralData(withMeasuredPower: power) as? [String: Any]
    mgr.startAdvertising(data)
    isAdvertising = true
  }

  private func stopAdvertising() {
    pendingStart = nil
    if let mgr = peripheralManager, mgr.isAdvertising {
      mgr.stopAdvertising()
    }
    isAdvertising = false
  }
}

extension AppDelegate: CBPeripheralManagerDelegate {
  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    if peripheral.state == .poweredOn {
      startPendingIfPossible()
    } else {
      // Ensure we don't claim to be advertising if BT is off.
      isAdvertising = false
    }
  }
}
