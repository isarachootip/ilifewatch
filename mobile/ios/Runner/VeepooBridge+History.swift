import Foundation
import VeepooBleSDK

extension VeepooBridge {
    // MARK: - History
    func syncHistory() {
        pm.veepooSdkStartReadDeviceAllData { [weak self] state, totalDay, currentDay, dayProgress in
            guard let self = self else { return }
            if state.rawValue == 1, totalDay > 0 { // reading
                let p = (Double(currentDay) + Double(dayProgress) / 100.0) / Double(totalDay)
                self.emit("syncProgress", ["progress": min(p, 1.0)])
            } else if state.rawValue == 2 { // complete
                self.exportDatabase(days: 3)
                self.emit("syncDone")
            }
        }
    }

    /// ดึงข้อมูลจากฐานข้อมูลภายในของ SDK แล้วส่งเป็น event รูปแบบเดียวกับ Android
    func exportDatabase(days: Int) {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        let tf = DateFormatter()
        tf.locale = Locale(identifier: "en_US_POSIX")
        tf.dateFormat = "yyyy-MM-dd HH:mm"

        for d in 0..<days {
            guard let day = Calendar.current.date(byAdding: .day, value: -d, to: Date()) else { continue }
            let date = df.string(from: day)
            func at(_ hhmm: String) -> Int? {
                guard let t = tf.date(from: "\(date) \(hhmm.prefix(5))") else { return nil }
                return Int(t.timeIntervalSince1970)
            }
            var vitals: [[String: Any]] = []

            if let origin = VPDataBaseOperation.veepooSDKGetOriginalData(withDate: date, andTableID: mac) {
                for (k, v) in origin {
                    guard let time = k as? String, let r = v as? [String: Any], let ts = at(time) else { continue }
                    if let hr = Self.int(r["heartValue"]), hr > 0 { vitals.append(["at": ts, "metric": "heart_rate", "value": Double(hr)]) }
                    if let st = Self.int(r["stepValue"]), st > 0 { vitals.append(["at": ts, "metric": "steps", "value": Double(st)]) }
                    if let s = Self.int(r["stress"]), s > 0 { vitals.append(["at": ts, "metric": "stress", "value": Double(s)]) }
                }
            }
            if let bps = VPDataBaseOperation.veepooSDKGetBloodData(withDate: date, andTableID: mac) {
                for case let r as [String: Any] in bps {
                    guard let time = r["Time"] as? String, let ts = at(time),
                          let sys = Self.int(r["systolic"]), let dia = Self.int(r["diastolic"]), sys > 0, dia > 0 else { continue }
                    let manual = (r["isManual"] as? String) == "Y"
                    self.emit("bpResult", ["method": "ppg", "status": "SUCCESS", "source": manual ? "watch" : "auto",
                                           "systolic": max(sys, dia), "diastolic": min(sys, dia), "at": ts])
                }
            }
            if let ox = VPDataBaseOperation.veepooSDKGetDeviceOxygenData(withDate: date, andTableID: mac) {
                for case let r as [String: Any] in ox {
                    guard let time = r["Time"] as? String, let ts = at(time),
                          let v = Self.int(r["OxygenValue"]), v > 0 else { continue }
                    vitals.append(["at": ts, "metric": "spo2", "value": Double(v)])
                }
            }
            if let temps = VPDataBaseOperation.veepooSDKGetDeviceTemperatureData(withDate: date, andTableID: mac) {
                for case let r as [String: Any] in temps {
                    guard let h = Self.int(r["hour"]), let m = Self.int(r["minute"]),
                          let ts = at(String(format: "%02d:%02d", h, m)),
                          let v = Self.double(r["value"]), v > 0 else { continue }
                    vitals.append(["at": ts, "metric": "temperature", "value": v])
                }
            }
            if !vitals.isEmpty { emit("vitals", ["samples": vitals]) }

            if let sleeps = VPDataBaseOperation.veepooSDKGetSleepData(withDate: date, andTableID: mac) {
                for case let s as [String: Any] in sleeps {
                    guard let start = Self.parseSlash(s["SLEEP_TIME"]), let end = Self.parseSlash(s["WAKE_TIME"]) else { continue }
                    emit("sleep", ["start": start, "end": end,
                                   "deep": Int((Self.double(s["DEEP_HOUR"]) ?? 0) * 60),
                                   "light": Int((Self.double(s["LIGHT_HOUR"]) ?? 0) * 60),
                                   "wake": Self.int(s["WakeUpTime"]) ?? 0,
                                   "quality": Self.int(s["SLEEP_LEVEL"]),
                                   "curve": s["SLE_LINE"] as? String])
                }
            }
            if manager.peripheralModel?.sleepType == 1,
               let acc = VPDataBaseOperation.veepooSDKGetAccurateSleepData(withDate: date, andTableID: mac) {
                for s in acc {
                    guard let start = Self.parseSlash(s.sleepTime), let end = Self.parseSlash(s.wakeTime) else { continue }
                    emit("sleep", ["start": start, "end": end,
                                   "deep": Int(s.deepDuration ?? "") ?? 0,
                                   "light": Int(s.lightDuration ?? "") ?? 0,
                                   "wake": Int(s.getUpTimes ?? "") ?? 0,
                                   "quality": Int(s.sleepQuality ?? ""),
                                   "curve": s.sleepLine])
                }
            }
            if let ecgs = VPDataBaseOperation.veepooSDKGetDeviceOffStoreECG(withDate: date, andTableID: mac) {
                for e in ecgs {
                    var m = ecgMap(e, waveform: Self.ints(e.filterSignals))
                    if let t = Self.parseSlash(e.testTime) ?? Self.parseSlash(e.date) { m["at"] = t }
                    m["source"] = "watch"
                    emit("ecgResult", m)
                }
            }
        }
    }

    // MARK: - helpers
    static func int(_ v: Any?) -> Int? {
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String { return Int(s) ?? Double(s).map { Int($0) } }
        return nil
    }

    static func double(_ v: Any?) -> Double? {
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String { return Double(s) }
        return nil
    }

    static func ints(_ a: [Any]?) -> [Int] {
        return (a ?? []).compactMap { int($0) }
    }

    static func parseSlash(_ v: Any?) -> Int? {
        guard let s = v as? String, !s.isEmpty else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        let norm = s.replacingOccurrences(of: "/", with: "-")
        for fmt in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"] {
            f.dateFormat = fmt
            if let d = f.date(from: norm) { return Int(d.timeIntervalSince1970) }
        }
        return nil
    }
}
