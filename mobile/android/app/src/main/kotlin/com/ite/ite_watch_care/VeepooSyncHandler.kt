package com.ite.ite_watch_care

import com.veepoo.protocol.listener.data.AbsDeviceManualDetectDataListener
import com.veepoo.protocol.listener.data.IAllHealthDataListener
import com.veepoo.protocol.listener.data.ISpo2hOriginDataListener
import com.veepoo.protocol.model.datas.BloodPressureManualData
import com.veepoo.protocol.model.datas.OriginData
import com.veepoo.protocol.model.datas.OriginHalfHourData
import com.veepoo.protocol.model.datas.SleepData
import com.veepoo.protocol.model.datas.Spo2hOriginData
import com.veepoo.protocol.model.enums.DeviceManualDataType

internal class VeepooSyncHandler(private val b: VeepooBridge) {

    fun syncHistory() {
        val vitals = ArrayList<Map<String, Any?>>()
        fun flush(force: Boolean = false) {
            if (vitals.isEmpty() || (!force && vitals.size < 100)) return
            b.emit("vitals", mapOf("samples" to ArrayList(vitals)))
            vitals.clear()
        }

        b.vp.readAllHealthData(object : IAllHealthDataListener {
            override fun onProgress(p: Float) {
                b.emit("syncProgress", mapOf("progress" to p.toDouble() * 0.8))
            }

            override fun onSleepDataChange(day: String?, s: SleepData?) {
                if (s == null || s.sleepDown == null || s.sleepUp == null) return
                b.emit("sleep", mapOf(
                    "start" to b.toEpochSec(s.sleepDown), "end" to b.toEpochSec(s.sleepUp),
                    "deep" to s.deepSleepTime, "light" to s.lowSleepTime,
                    "wake" to s.wakeCount, "quality" to s.sleepQulity, "curve" to s.sleepLine,
                ))
            }

            override fun onReadSleepComplete() {}

            override fun onOringinFiveMinuteDataChange(o: OriginData?) {
                val t = o?.getmTime() ?: return
                val at = b.toEpochSec(t)
                if (o.rateValue > 0) vitals.add(b.sample(at, "heart_rate", o.rateValue.toDouble()))
                if (o.stepValue > 0) vitals.add(b.sample(at, "steps", o.stepValue.toDouble()))
                if (o.temperature > 0) vitals.add(b.sample(at, "temperature", o.temperature))
                if (o.highValue > 0 && o.lowValue > 0) {
                    b.emit("bpResult", mapOf(
                        "method" to "ppg", "status" to "SUCCESS", "source" to "auto",
                        "systolic" to o.highValue, "diastolic" to o.lowValue, "at" to at,
                    ))
                }
                flush()
            }

            override fun onOringinHalfHourDataChange(o: OriginHalfHourData?) {}

            override fun onReadOriginComplete() {
                flush(force = true)
                readSpo2(vitals) // ต่อด้วย SpO2 แล้วจึงส่ง syncDone
            }
        }, b.watchDays)
    }

    private fun readSpo2(vitals: ArrayList<Map<String, Any?>>) {
        b.vp.readSpo2hOrigin(b.writeResp, object : ISpo2hOriginDataListener {
            override fun onReadOriginProgress(p: Float) {
                b.emit("syncProgress", mapOf("progress" to 0.8 + p.toDouble() * 0.2))
            }
            override fun onReadOriginProgressDetail(day: Int, date: String?, all: Int, cur: Int) {}
            override fun onSpo2hOriginListener(d: Spo2hOriginData?) {
                val t = d?.getmTime() ?: return
                if (d.oxygenValue > 0) vitals.add(b.sample(b.toEpochSec(t), "spo2", d.oxygenValue.toDouble()))
                if (vitals.size >= 100) {
                    b.emit("vitals", mapOf("samples" to ArrayList(vitals)))
                    vitals.clear()
                }
            }
            override fun onReadOriginComplete() {
                if (vitals.isNotEmpty()) {
                    b.emit("vitals", mapOf("samples" to ArrayList(vitals)))
                    vitals.clear()
                }
                b.emit("syncDone")
            }
        }, b.watchDays)
    }

    /** ผลที่ผู้ใช้กดวัดเองบนนาฬิกา (ความดันปั๊มลมจะอยู่ในนี้) */
    fun readManual(sinceSec: Long) {
        // ตาม bytecode ของ vp_aa: list1 (byte 6..9) คือชนิดข้อมูลที่ขออ่าน, list2 (byte 10..13) คือชนิดที่เครื่องรองรับ
        val requested = listOf(DeviceManualDataType.BLOOD_PRESSURE)
        val supported = b.vp.supportManualDetectTypes?.takeIf { it.isNotEmpty() } ?: requested
        b.vp.readDeviceManualData(
            b.writeResp,
            sinceSec,
            requested,
            supported,
            object : AbsDeviceManualDetectDataListener() {
                override fun onBloodPressureDataChange(list: List<BloodPressureManualData>?) {
                    list?.forEach { d ->
                        b.emit("bpResult", mapOf(
                            // measurementMode: 0 = แสง (PPG), 1 = ถุงลม (Cuff)
                            "method" to if (d.measurementMode == 1) "cuff" else "ppg",
                            "status" to "SUCCESS", "source" to "watch",
                            "systolic" to d.systolic, "diastolic" to d.diastolic,
                            "pulse" to d.heartRate, "credibility" to d.resultCredibility,
                            "at" to d.timeStamp,
                        ))
                    }
                }
                override fun onReadComplete() { b.emit("manualDone") }
                override fun onReadFail() { b.emit("manualDone", mapOf("error" to true)) }
            },
        )
    }
}
