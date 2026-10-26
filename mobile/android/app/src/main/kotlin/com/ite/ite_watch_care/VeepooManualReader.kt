package com.ite.ite_watch_care

import com.veepoo.protocol.listener.data.AbsDeviceManualDetectDataListener
import com.veepoo.protocol.model.datas.BloodOxygenManualData
import com.veepoo.protocol.model.datas.BloodPressureManualData
import com.veepoo.protocol.model.datas.BodyTemperatureManualData
import com.veepoo.protocol.model.datas.HeartRateManualData
import com.veepoo.protocol.model.datas.HrvManualData
import com.veepoo.protocol.model.datas.MiniCheckupManualData
import com.veepoo.protocol.model.datas.PressureManualData
import com.veepoo.protocol.model.enums.DeviceManualDataType

/**
 * อ่านข้อมูลที่ผู้ใช้กดวัดเองบนตัวนาฬิกา (ตาม DeviceManualTestDataActivity.java ใน Joeme Fit SDK 260626_new)
 * รองรับทั้งความดัน (ถุงลม/แสง), ชีพจร, SpO2, อุณหภูมิ, ความเครียด, HRV และผลการตรวจสุขภาพด่วน (Mini Checkup)
 */
internal class VeepooManualReader(private val b: VeepooBridge) {

    fun readManual(sinceSec: Long) {
        val requested = listOf(DeviceManualDataType.ALL)
        val supported = b.vp.supportManualDetectTypes?.takeIf { it.isNotEmpty() } ?: requested
        val vitals = ArrayList<Map<String, Any?>>()

        fun emitVitals() {
            if (vitals.isEmpty()) return
            b.emit("vitals", mapOf("samples" to ArrayList(vitals)))
            vitals.clear()
        }

        b.vp.readDeviceManualData(
            b.writeResp,
            sinceSec,
            requested,
            supported,
            object : AbsDeviceManualDetectDataListener() {
                override fun onBloodPressureDataChange(list: List<BloodPressureManualData>?) {
                    list?.forEach { d ->
                        if (d.systolic > 0 && d.diastolic > 0) {
                            b.emit("bpResult", mapOf(
                                "method" to if (d.measurementMode == 1) "cuff" else "ppg",
                                "status" to "SUCCESS",
                                "source" to "watch",
                                "systolic" to d.systolic,
                                "diastolic" to d.diastolic,
                                "pulse" to d.heartRate,
                                "credibility" to d.resultCredibility,
                                "at" to d.timeStamp.toLong(),
                            ))
                        }
                    }
                }

                override fun onHeartRateDataChange(list: List<HeartRateManualData>?) {
                    list?.forEach { d ->
                        val hr = d.rate?.lastOrNull { it in 30..240 } ?: return@forEach
                        vitals.add(b.sample(d.timeStamp.toLong(), "heart_rate", hr.toDouble()))
                    }
                }

                override fun onBloodOxygenDataChange(list: List<BloodOxygenManualData>?) {
                    list?.forEach { d ->
                        val oxy = d.oxygen?.lastOrNull { it in 50..100 } ?: return@forEach
                        vitals.add(b.sample(d.timeStamp.toLong(), "spo2", oxy.toDouble()))
                    }
                }

                override fun onBodyTemperatureDataChange(list: List<BodyTemperatureManualData>?) {
                    list?.forEach { d ->
                        val temp = d.temperature.toDouble()
                        if (temp in 30.0..45.0) {
                            vitals.add(b.sample(d.timeStamp.toLong(), "temperature", temp))
                        }
                    }
                }

                override fun onPressureManualDataChange(list: List<PressureManualData>?) {
                    list?.forEach { d ->
                        if (d.pressure > 0) {
                            vitals.add(b.sample(d.timeStamp.toLong(), "stress", d.pressure.toDouble()))
                        }
                    }
                }

                override fun onHrvManualDataChange(list: List<HrvManualData>?) {
                    list?.forEach { d ->
                        val hrv = d.hrv?.lastOrNull { it in 1..254 } ?: return@forEach
                        vitals.add(b.sample(d.timeStamp.toLong(), "hrv", hrv.toDouble()))
                    }
                }

                override fun onMiniCheckupManualDataChange(list: List<MiniCheckupManualData>?) {
                    list?.forEach { d ->
                        val ts = d.timeStamp.toLong()
                        if (d.highValue > 0 && d.lowValue > 0) {
                            b.emit("bpResult", mapOf(
                                "method" to "ppg",
                                "status" to "SUCCESS",
                                "source" to "watch",
                                "systolic" to d.highValue,
                                "diastolic" to d.lowValue,
                                "pulse" to d.heart,
                                "at" to ts,
                            ))
                        }
                        if (d.heart in 30..240) vitals.add(b.sample(ts, "heart_rate", d.heart.toDouble()))
                        if (d.oxygen in 50..100) vitals.add(b.sample(ts, "spo2", d.oxygen.toDouble()))
                        val temp = d.temperature.toDouble()
                        if (temp in 30.0..45.0) vitals.add(b.sample(ts, "temperature", temp))
                        if (d.hrv in 1..254) vitals.add(b.sample(ts, "hrv", d.hrv.toDouble()))
                        if (d.pressure > 0) vitals.add(b.sample(ts, "stress", d.pressure.toDouble()))
                    }
                }

                override fun onReadComplete() {
                    emitVitals()
                    b.emit("manualDone")
                }

                override fun onReadFail() {
                    emitVitals()
                    b.emit("manualDone", mapOf("error" to true))
                }
            },
        )
    }
}
