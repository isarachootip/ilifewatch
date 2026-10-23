import Foundation
import VeepooBleSDK

extension VeepooBridge {
    // MARK: - Blood pressure
    /// iOS SDK ใช้คำสั่งเดียวสำหรับวัดความดัน — นาฬิกาที่มีถุงลมจะใช้ปั๊มลมเอง
    /// ผลที่บันทึกบนนาฬิกาจะบอกวิธีวัด (testModel) ใน readManual
    func startBp() {
        pm.veepooSDKTestBloodStart(true, testMode: 0) { [weak self] state, progress, high, low in
            guard let self = self else { return }
            switch state.rawValue {
            case 0: // testing
                self.emit("bpProgress", ["progress": Int(progress), "systolic": Int(high), "diastolic": Int(low)])
            case 4: // complete
                self.emit("bpResult", ["method": "cuff", "status": "SUCCESS", "source": "live",
                                       "systolic": Int(high), "diastolic": Int(low),
                                       "at": Int(Date().timeIntervalSince1970)])
            case 1: self.emit("bpError", ["status": "DEVICE_BUSY"])
            case 2: self.emit("bpError", ["status": "FAILED"])
            case 3: self.emit("bpError", ["status": "INTERRUPTED"])
            default: self.emit("bpError", ["status": "NO_FUNCTION"])
            }
        }
    }

    // MARK: - ECG
    func startEcg() {
        ecgSentCount = 0
        pm.veepooSDKTestECGStart(true) { [weak self] state, progress, model in
            guard let self = self else { return }
            let wave = Self.ints(model?.filterSignals)
            if wave.count > self.ecgSentCount {
                self.emit("ecgWave", ["samples": Array(wave[self.ecgSentCount...])])
                self.ecgSentCount = wave.count
            }
            switch state.rawValue {
            case 0, 1: // start / testing
                self.emit("ecgProgress", ["progress": Int(progress),
                                          "heartRate": (model?.hearts?.last as? NSNumber)?.intValue,
                                          "leadOff": false])
            case 2: // lead off
                self.emit("ecgProgress", ["progress": Int(progress), "leadOff": true])
            case 6: // complete
                self.emit("ecgResult", self.ecgMap(model, waveform: wave))
            case 4: // ended by user
                self.emit("ecgError", ["status": "INTERRUPTED"])
            case 3:
                self.emit("ecgError", ["status": "DEVICE_BUSY"])
            default:
                self.emit("ecgError", ["status": "FAILED"])
            }
        }
    }

    func ecgMap(_ m: VPECGTestDataModel?, waveform: [Int]) -> [String: Any?] {
        return [
            "at": Int(Date().timeIntervalSince1970),
            "duration": Int(m?.duration ?? "") ?? 0,
            "sampleRate": Int(m?.frequency ?? "") ?? 0,
            "aveHeart": Int(m?.aveHeart ?? ""),
            "aveHrv": Int(m?.aveHrv ?? ""),
            "aveQt": Int(m?.aveQT ?? ""),
            "aveResp": Int(m?.aveResRate ?? ""),
            "waveform": waveform,
        ]
    }

    /// ผลที่ผู้ใช้กดวัดเองบนนาฬิกา (testModel 1 = ถุงลม)
    func readManual(since: UInt32) {
        var finished = false
        pm.readManualTestData(withTimestamp: since, dataType: VPManualTestDataType(rawValue: 1)) { [weak self] model in
            guard let self = self else { return }
            for b in model.bloodPressureArr {
                self.emit("bpResult", ["method": b.testModel == 1 ? "cuff" : "ppg", "status": "SUCCESS",
                                       "source": "watch", "systolic": Int(b.h_bp), "diastolic": Int(b.l_bp),
                                       "pulse": Int(b.heart), "credibility": Int(b.credibility),
                                       "at": Int(b.timestamp)])
            }
            if !finished { finished = true; self.emit("manualDone") }
        }
        // SDK ไม่มี callback แจ้งว่าไม่มีข้อมูล — กันค้างด้วย timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            if !finished { finished = true; self?.emit("manualDone") }
        }
    }
}
