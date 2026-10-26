package com.ite.ite_watch_care

import com.veepoo.protocol.listener.data.IAllHealthDataListener
import com.veepoo.protocol.listener.data.IOriginData3Listener
import com.veepoo.protocol.listener.data.ISleepDataListener
import com.veepoo.protocol.listener.data.ISpo2hOriginDataListener
import com.veepoo.protocol.model.datas.HRVOriginData
import com.veepoo.protocol.model.datas.OriginData
import com.veepoo.protocol.model.datas.OriginData3
import com.veepoo.protocol.model.datas.OriginHalfHourData
import com.veepoo.protocol.model.datas.SleepData
import com.veepoo.protocol.model.datas.Spo2hOriginData

/**
 * ซิงค์ข้อมูลย้อนหลังจากนาฬิกา (ตาม HealthDataReadOptActivity.java & OperaterActivity.java ใน Joeme Fit SDK 260626_new)
 * - รองรับทั้ง Origin Protocol v3+ (OriginData3 สำหรับ F520Pro) และ OriginData รุ่นก่อนหน้า
 * - รองรับการอ่านข้อมูลการนอนหลับทั้ง SleepData และ SleepPrecisionData
 */
internal class VeepooSyncHandler(private val b: VeepooBridge) {

    fun syncHistory() {
        val vitals = ArrayList<Map<String, Any?>>()
        fun flush(force: Boolean = false) {
            if (vitals.isEmpty() || (!force && vitals.size < 100)) return
            b.emit("vitals", mapOf("samples" to ArrayList(vitals)))
            vitals.clear()
        }

        if (b.originProtocolVersion >= 3) {
            b.vp.readSleepData(b.writeResp, object : ISleepDataListener {
                override fun onSleepDataChange(day: String?, s: SleepData?) {
                    emitSleep(s)
                }
                override fun onSleepProgress(p: Float) {
                    b.emit("syncProgress", mapOf("progress" to p.toDouble() * 0.2))
                }
                override fun onSleepProgressDetail(day: String?, pack: Int) {}
                override fun onReadSleepComplete() {
                    readOriginV3(vitals, ::flush)
                }
            }, b.watchDays)
        } else {
            syncLegacyAllHealth(vitals, ::flush)
        }
    }

    private fun emitSleep(s: SleepData?) {
        if (s == null || s.sleepDown == null || s.sleepUp == null) return
        b.emit("sleep", mapOf(
            "start" to b.toEpochSec(s.sleepDown),
            "end" to b.toEpochSec(s.sleepUp),
            "deep" to s.deepSleepTime,
            "light" to s.lowSleepTime,
            "wake" to s.wakeCount,
            "quality" to s.sleepQulity,
            "curve" to s.sleepLine,
        ))
    }

    private fun readOriginV3(vitals: ArrayList<Map<String, Any?>>, flush: (Boolean) -> Unit) {
        b.vp.readOriginData(b.writeResp, object : IOriginData3Listener {
            override fun onOriginFiveMinuteListDataChange(list: List<OriginData3>?) {
                list?.forEach { o ->
                    val t = o.getmTime() ?: return@forEach
                    val at = b.toEpochSec(t)
                    if (o.rateValue > 0) vitals.add(b.sample(at, "heart_rate", o.rateValue.toDouble()))
                    if (o.stepValue > 0) vitals.add(b.sample(at, "steps", o.stepValue.toDouble()))
                    if (o.temperature > 0) vitals.add(b.sample(at, "temperature", o.temperature))
                    val oxy = o.oxygens?.lastOrNull { it in 50..100 }
                    if (oxy != null) vitals.add(b.sample(at, "spo2", oxy.toDouble()))
                    if (o.pressure > 0) vitals.add(b.sample(at, "stress", o.pressure.toDouble()))
                    if (o.highValue > 0 && o.lowValue > 0) {
                        b.emit("bpResult", mapOf(
                            "method" to "ppg", "status" to "SUCCESS", "source" to "auto",
                            "systolic" to o.highValue, "diastolic" to o.lowValue, "at" to at,
                        ))
                    }
                    flush(false)
                }
            }

            override fun onOriginHalfHourDataChange(h: OriginHalfHourData?) {}

            override fun onOriginHRVOriginListDataChange(list: List<HRVOriginData>?) {
                list?.forEach { h ->
                    val t = h.getmTime() ?: return@forEach
                    val v = h.hrvValue
                    if (v in 1..254) vitals.add(b.sample(b.toEpochSec(t), "hrv", v.toDouble()))
                }
                flush(false)
            }

            override fun onOriginSpo2OriginListDataChange(list: List<Spo2hOriginData>?) {
                list?.forEach { d ->
                    val t = d.getmTime() ?: return@forEach
                    if (d.oxygenValue in 50..100) {
                        vitals.add(b.sample(b.toEpochSec(t), "spo2", d.oxygenValue.toDouble()))
                    }
                }
                flush(false)
            }

            override fun onReadOriginProgressDetail(day: Int, date: String?, all: Int, cur: Int) {}

            override fun onReadOriginProgress(p: Float) {
                b.emit("syncProgress", mapOf("progress" to 0.2 + p.toDouble() * 0.8))
            }

            override fun onReadOriginComplete() {
                flush(true)
                b.emit("syncDone")
            }
        }, b.watchDays)
    }

    private fun syncLegacyAllHealth(vitals: ArrayList<Map<String, Any?>>, flush: (Boolean) -> Unit) {
        b.vp.readAllHealthData(object : IAllHealthDataListener {
            override fun onProgress(p: Float) {
                b.emit("syncProgress", mapOf("progress" to p.toDouble() * 0.8))
            }

            override fun onSleepDataChange(day: String?, s: SleepData?) {
                emitSleep(s)
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
                flush(false)
            }

            override fun onOringinHalfHourDataChange(o: OriginHalfHourData?) {}

            override fun onReadOriginComplete() {
                flush(true)
                readSpo2(vitals)
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
}
