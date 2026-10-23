package com.ite.ite_watch_care

import com.veepoo.protocol.listener.data.IBPDetectDataListener
import com.veepoo.protocol.listener.data.ICuffBPDetectDataListener
import com.veepoo.protocol.listener.data.IECGDetectListener
import com.veepoo.protocol.model.datas.BpData
import com.veepoo.protocol.model.datas.EcgDetectInfo
import com.veepoo.protocol.model.datas.EcgDetectResult
import com.veepoo.protocol.model.datas.EcgDetectState
import com.veepoo.protocol.model.datas.EcgDiagnosis
import com.veepoo.protocol.model.datas.VPCuffBPTestData
import com.veepoo.protocol.model.enums.EBPDetectModel
import com.veepoo.protocol.model.enums.EBPDetectStatus
import com.veepoo.protocol.model.enums.EVPCuffBPTestStatus

internal class VeepooMeasureHandler(private val b: VeepooBridge) {

    private var ppgBpResultSent = false
    private val ecgWave = ArrayList<Int>()
    private var ecgSampleRate = 0

    // ----------------------------------------------------------------- blood pressure
    fun startBp(method: String) {
        if (method == "cuff") {
            // วัดด้วยปั๊มลม (ถุงลมในสาย): พารามิเตอร์ boolean ตัวที่ 2 คือการเปิดรับ raw ADC stream (PPG/Gsensor/Cuff)
            // ส่ง false เพื่อวัดความดันตามปกติโดยไม่ดึงข้อมูล raw ADC โรงงาน
            b.vp.startDetectCuffBP(b.writeResp, false, object : ICuffBPDetectDataListener {
                override fun onCuffDataChange(finished: Boolean, d: VPCuffBPTestData?) {
                    if (d == null) return
                    when (d.status) {
                        EVPCuffBPTestStatus.SUCCESS -> b.emit("bpResult", mapOf(
                            "method" to "cuff", "status" to "SUCCESS", "source" to "live",
                            "systolic" to d.sbpValue, "diastolic" to d.dbpValue, "pulse" to d.heartValue,
                            "at" to b.nowSec(),
                        ))
                        EVPCuffBPTestStatus.EMPTY, null -> b.emit("bpProgress", mapOf(
                            "progress" to d.rate, "pressure" to d.pressureValue,
                            "systolic" to d.sbpValue, "diastolic" to d.dbpValue,
                        ))
                        else -> b.emit("bpError", mapOf("method" to "cuff", "status" to d.status.name))
                    }
                }
            })
        } else {
            ppgBpResultSent = false
            b.vp.startDetectBP(b.writeResp, object : IBPDetectDataListener {
                override fun onDataChange(d: BpData?) {
                    if (d == null) return
                    if (d.status != EBPDetectStatus.STATE_BP_NORMAL) {
                        b.emit("bpError", mapOf("method" to "ppg", "status" to d.status.name.removePrefix("STATE_BP_")))
                        return
                    }
                    b.emit("bpProgress", mapOf("progress" to d.progress,
                        "systolic" to d.highPressure, "diastolic" to d.lowPressure))
                    // Javadoc: ค่าที่ใช้ได้คือค่าแรกที่ progress = 100 แล้วต้อง stop ทันที
                    if (d.progress >= 100 && !ppgBpResultSent) {
                        ppgBpResultSent = true
                        b.vp.stopDetectBP(b.writeResp, EBPDetectModel.DETECT_MODEL_PUBLIC)
                        b.emit("bpResult", mapOf(
                            "method" to "ppg", "status" to "SUCCESS", "source" to "live",
                            "systolic" to d.highPressure, "diastolic" to d.lowPressure, "at" to b.nowSec(),
                        ))
                    }
                }
            }, EBPDetectModel.DETECT_MODEL_PUBLIC)
        }
    }

    fun stopBp(method: String) {
        if (method == "cuff") b.vp.stopDetectCuffBP(b.writeResp)
        else b.vp.stopDetectBP(b.writeResp, EBPDetectModel.DETECT_MODEL_PUBLIC)
    }

    // ----------------------------------------------------------------- ECG
    // ต้องมี libnative-lib.so (jniLibs) ในโปรเจกต์ ไม่อย่างนั้นฟังก์ชัน ECG จะ crash
    private val ecgListener = object : IECGDetectListener {
        override fun onEcgDetectInfoChange(info: EcgDetectInfo?) {
            if (info != null) ecgSampleRate = info.frequency
        }

        override fun onEcgDetectStateChange(s: EcgDetectState?) {
            if (s == null) return
            if (s.con == 0) {
                b.emit("ecgError", mapOf("status" to "NO_FUNCTION"))
                return
            }
            // ตาม Javadoc EcgDetectState: wear == 0 คือสัมผัสขั้วผ่าน, wear == 1 คือไม่ได้แตะขั้ว (leadOff)
            // ส่วน hrv == 255 คือค่าไม่ถูกต้อง ไม่ต้องแสดงผล
            b.emit("ecgProgress", mapOf(
                "progress" to s.progress,
                "heartRate" to s.hr1,
                "hrv" to s.hrv.takeIf { it in 1..254 },
                "leadOff" to (s.wear != 0),
            ))
        }

        override fun onEcgDetectResultChange(r: EcgDetectResult?) {
            if (r == null) return
            if (!r.isSuccess) {
                b.emit("ecgError", mapOf("status" to "FAILED"))
                return
            }
            val wave = r.filterSignals?.toList()?.takeIf { it.isNotEmpty() }
                ?: r.originSign?.toList()?.takeIf { it.isNotEmpty() }
                ?: ecgWave.toList()
            b.emit("ecgResult", mapOf(
                "at" to (r.timeBean?.let { b.toEpochSec(it) } ?: b.nowSec()),
                "duration" to r.duration,
                "sampleRate" to (if (r.frequency > 0) r.frequency else ecgSampleRate),
                "aveHeart" to r.aveHeart, "aveHrv" to r.aveHrv,
                "aveQt" to r.aveQT, "aveResp" to r.aveResRate,
                "waveform" to wave,
            ))
        }

        // ผลวินิจฉัย/ความเสี่ยงโรค เป็นส่วนที่ต้องซื้อลิขสิทธิ์แยก และมีประเด็น อย. — ไม่ส่งต่อ
        override fun onEcgDetectDiagnosisChange(d: EcgDiagnosis?) {}

        override fun onEcgADCChange(raw: IntArray?, filtered: IntArray?) {
            val pts = filtered ?: raw ?: return
            ecgWave.addAll(pts.toList())
            b.emit("ecgWave", mapOf("samples" to pts.toList()))
        }
    }

    fun startEcg() {
        ecgWave.clear()
        b.vp.startDetectECG(b.writeResp, true, ecgListener)
    }

    fun stopEcg() {
        b.vp.stopDetectECG(b.writeResp, true, ecgListener)
    }
}
