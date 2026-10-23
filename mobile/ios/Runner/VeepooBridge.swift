import Flutter
import Foundation
import VeepooBleSDK

/// ตัวเชื่อม Flutter <-> Veepoo iOS SDK (VeepooBleSDK.framework 2.2.XX.15)
/// ส่ง event รูปแบบเดียวกับฝั่ง Android (ดู lib/watch/watch_service.dart)
///
/// ต่างจาก Android: SDK iOS ส่งรหัสผ่าน (ค่าเริ่มต้น 0000) ให้อัตโนมัติหลังเชื่อมต่อ
/// และเก็บข้อมูลย้อนหลังลงฐานข้อมูลภายใน SDK ก่อน เราจึงอ่านจาก VPDataBaseOperation หลัง sync เสร็จ
final class VeepooBridge: NSObject, FlutterStreamHandler {
    let manager: VPBleCentralManage = VPBleCentralManage.sharedBleManager()
    var sink: FlutterEventSink?
    var scanned: [String: VPPeripheralModel] = [:]
    var ecgSentCount = 0

    init(messenger: FlutterBinaryMessenger) {
        super.init()
        let method = FlutterMethodChannel(name: "ite.watch/method", binaryMessenger: messenger)
        let events = FlutterEventChannel(name: "ite.watch/events", binaryMessenger: messenger)
        events.setStreamHandler(self)
        method.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
        manager.isLogEnable = false
        manager.vpBleConnectStateChangeBlock = { [weak self] (state: VPDeviceConnectState) in
            // 0 = VPDeviceConnectStateDisConnect
            if state.rawValue == 0 { self?.emit("connection", ["state": "disconnected"]) }
        }
    }

    // MARK: - FlutterStreamHandler
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }

    func emit(_ type: String, _ data: [String: Any?] = [:]) {
        var m: [String: Any] = ["type": type]
        for (k, v) in data { if let v = v { m[k] = v } }
        DispatchQueue.main.async { self.sink?(m) }
    }

    var pm: VPPeripheralBaseManage { manager.peripheralManage }
    var mac: String { manager.peripheralModel?.deviceAddress ?? "" }

    // MARK: - Method calls
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "startScan":
            scanned.removeAll()
            manager.veepooSDKStartScanDeviceAndReceiveScanningDevice { [weak self] model in
                guard let self = self, let model = model else { return }
                self.scanned[model.deviceAddress] = model
                self.emit("scan", ["name": model.deviceName ?? "", "mac": model.deviceAddress,
                                   "rssi": model.rssi?.intValue ?? 0])
            }
            result(nil)
        case "stopScan":
            manager.veepooSDKStopScanDevice()
            result(nil)
        case "connect":
            guard let mac = args["mac"] as? String, let model = scanned[mac] else {
                result(FlutterError(code: "NOT_FOUND", message: "ไม่พบนาฬิกาในผลการสแกน", details: nil))
                return
            }
            connect(model)
            result(nil)
        case "disconnect":
            manager.veepooSDKDisconnectDevice()
            result(nil)
        case "syncProfile":
            syncProfile(args, result: result)
        case "readBattery":
            pm.veepooSDKReadDeviceBatteryInfo { [weak self] isPercent, isLow, battery in
                self?.emit("battery", ["isPercent": isPercent, "percent": isPercent ? Int(battery) : nil,
                                       "level": Int(battery), "low": isLow])
            }
            result(nil)
        case "startBp":
            startBp()
            result(nil)
        case "stopBp":
            pm.veepooSDKTestBloodStart(false, testMode: 0, testResult: nil)
            result(nil)
        case "startEcg":
            startEcg()
            result(nil)
        case "stopEcg":
            pm.veepooSDKTestECGStart(false, testResult: nil)
            result(nil)
        case "syncHistory":
            syncHistory()
            result(nil)
        case "readWatchMeasurements":
            let since = (args["since"] as? NSNumber)?.uint32Value ?? 0
            readManual(since: since)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Connect
    private func connect(_ model: VPPeripheralModel) {
        manager.veepooSDKStopScanDevice()
        emit("connection", ["state": "connecting"])
        manager.veepooSDKConnectDevice(model) { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .BleConnectSuccess:
                self.emit("connection", ["state": "connected"])
            case .BleVerifyPasswordSuccess:
                let p = self.manager.peripheralModel
                self.emit("connection", ["state": "ready"])
                self.emit("deviceInfo", ["mac": p?.deviceAddress, "name": p?.deviceName,
                                         "firmware": p?.deviceVersion])
                self.emit("capabilities", ["bp": p?.isSupportBPTest ?? false,
                                           "ecg": (p?.ecgType ?? 0) > 0,
                                           "watchDays": 3])
            case .BleConnecting:
                break
            default:
                self.emit("connection", ["state": "failed", "detail": "state=\(state.rawValue)"])
            }
        }
    }

    private func syncProfile(_ a: [String: Any], result: @escaping FlutterResult) {
        let isMale = a["isMale"] as? Bool ?? false
        pm.veepooSDKSynchronousPersonalInformation(
            withStature: UInt(a["heightCm"] as? Int ?? 160),
            weight: UInt(a["weightKg"] as? Int ?? 60),
            birth: UInt(a["birthYear"] as? Int ?? 1965),
            sex: isMale ? 1 : 0,
            targetStep: UInt(a["stepGoal"] as? Int ?? 6000)
        ) { settingResult in
            DispatchQueue.main.async {
                if settingResult == 1 { result(nil) }
                else { result(FlutterError(code: "PROFILE_FAILED", message: "sync profile failed", details: nil)) }
            }
        }
    }
}
