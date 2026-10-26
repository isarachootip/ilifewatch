package com.ite.ite_watch_care

import com.veepoo.protocol.listener.data.IHeartDataListener
import com.veepoo.protocol.listener.data.ISpo2hDataListener
import com.veepoo.protocol.listener.data.ISportDataListener
import com.veepoo.protocol.listener.data.ISportModelStateListener
import com.veepoo.protocol.listener.data.ITemptureDetectDataListener
import com.veepoo.protocol.model.datas.HeartData
import com.veepoo.protocol.model.datas.Spo2hData
import com.veepoo.protocol.model.datas.SportData
import com.veepoo.protocol.model.datas.SportModelStateData
import com.veepoo.protocol.model.datas.TemptureDetectData
import com.veepoo.protocol.model.enums.EHeartStatus
import com.veepoo.protocol.model.enums.ESPO2HStatus
import com.veepoo.protocol.model.enums.ESportType

/**
 * จัดการคำสั่งวัดค่าสดจากนาฬิกา F520Pro:
 * - ออกซิเจนในเลือด (SpO2): startDetectSPO2H / stopDetectSPO2H
 * - อุณหภูมิร่างกาย (Temp): startDetectTempture / stopDetectTempture
 * - อัตราการเต้นหัวใจสด (Heart Rate): startDetectHeart / stopDetectHeart
 * - ก้าวเดิน/ระยะทาง/แคลอรีปัจจุบัน: readSportStep
 * - สั่งเริ่ม/หยุดโหมดออกกำลังกายบนนาฬิกา: startMultSportModel / stopSportModel
 */
internal class VeepooLiveVitalHandler(private val b: VeepooBridge) {

    // ----------------------------------------------------------------- Live SpO2
    private val spo2Listener = object : ISpo2hDataListener {
        override fun onSpO2HADataChange(d: Spo2hData?) {
            if (d == null) return
            if (d.spState == ESPO2HStatus.NOT_SUPPORT) {
                b.emit("spo2Error", mapOf("status" to "NO_FUNCTION"))
                return
            }
            if (d.value in 50..100) {
                b.emit("spo2Result", mapOf(
                    "value" to d.value,
                    "heartRate" to d.rateValue,
                    "progress" to d.checkingProgress,
                    "at" to b.nowSec(),
                ))
            } else {
                b.emit("spo2Progress", mapOf(
                    "progress" to d.checkingProgress,
                    "checking" to d.isChecking,
                    "deviceState" to d.deviceState?.name,
                ))
            }
        }
    }

    fun startSpo2() {
        b.vp.startDetectSPO2H(b.writeResp, spo2Listener)
    }

    fun stopSpo2() {
        b.vp.stopDetectSPO2H(b.writeResp, spo2Listener)
    }

    // ----------------------------------------------------------------- Live Body Temperature
    private val tempListener = object : ITemptureDetectDataListener {
        override fun onDataChange(d: TemptureDetectData?) {
            if (d == null) return
            // ตาม BodyTemperatureDetectActivity.java ใน Joeme Fit SDK 260626_new:
            // oprate: 0x00 = ไม่รองรับ, 0x01 = กำลังวัด, 0x02 = หยุดวัด
            // deviceState: 0 = ปกติ, 1..6 = เครื่องไม่ว่าง, 8 = แบตต่ำ, 9 = เซนเซอร์ผิดพลาด
            if (d.oprate == 0) {
                b.emit("tempError", mapOf("status" to "NO_FUNCTION"))
                return
            }
            when (d.deviceState) {
                in 1..6 -> {
                    b.emit("tempError", mapOf("status" to "DEVICE_BUSY"))
                    return
                }
                8 -> {
                    b.emit("tempError", mapOf("status" to "LOW_POWER"))
                    return
                }
                9 -> {
                    b.emit("tempError", mapOf("status" to "SENSOR_ERROR"))
                    return
                }
            }
            if (d.tempture > 30f && d.progress >= 100) {
                b.emit("tempResult", mapOf(
                    "celsius" to d.tempture.toDouble(),
                    "base" to d.temptureBase.toDouble(),
                    "progress" to d.progress,
                    "at" to b.nowSec(),
                ))
            } else if (d.oprate != 2) {
                b.emit("tempProgress", mapOf(
                    "progress" to d.progress,
                    "celsius" to if (d.tempture > 0f) d.tempture.toDouble() else null,
                ))
            }
        }
    }

    fun startTemp() {
        b.vp.startDetectTempture(b.writeResp, tempListener)
    }

    fun stopTemp() {
        b.vp.stopDetectTempture(b.writeResp, tempListener)
    }

    // ----------------------------------------------------------------- Live Heart Rate
    fun startHeart() {
        b.vp.startDetectHeart(b.writeResp, object : IHeartDataListener {
            override fun onDataChange(d: HeartData?) {
                if (d == null) return
                if (d.heartStatus == EHeartStatus.STATE_HEART_WEAR_ERROR) {
                    b.emit("heartError", mapOf("status" to "WEAR_OFF"))
                    return
                }
                if (d.data in 30..240) {
                    b.emit("heartResult", mapOf("bpm" to d.data, "at" to b.nowSec()))
                } else {
                    b.emit("heartProgress", mapOf("status" to d.heartStatus?.name))
                }
            }
        })
    }

    fun stopHeart() {
        b.vp.stopDetectHeart(b.writeResp)
    }

    // ----------------------------------------------------------------- Live Steps & Sport Mode
    fun readSportStep() {
        b.vp.readSportStep(b.writeResp, object : ISportDataListener {
            override fun onSportDataChange(d: SportData?) {
                if (d == null) return
                b.emit("sportStep", mapOf(
                    "steps" to d.step,
                    "distanceKm" to d.dis,
                    "kcal" to d.kcal.toInt(),
                    "at" to b.nowSec(),
                ))
            }
        })
    }

    private val sportStateListener = object : ISportModelStateListener {
        override fun onSportModelStateChange(s: SportModelStateData?) {
            if (s == null) return
            b.emit("sportState", mapOf(
                "running" to true,
                "deviceStatus" to s.deviceStauts?.name,
                "operateStatus" to s.oprateStauts?.name,
                "sportType" to s.sportModeType,
            ))
        }

        override fun onSportStopped() {
            b.emit("sportState", mapOf("running" to false))
        }
    }

    fun startSportMode(mode: String) {
        val type = when (mode) {
            "walk" -> ESportType.OUTDOOR_WALK
            "run_out" -> ESportType.OUTDOOR_RUNNING
            "run_in" -> ESportType.INDOOR_RUNNING
            "cycle" -> ESportType.OUTDOOR_RIDING
            else -> ESportType.OUTDOOR_WALK
        }
        b.vp.startMultSportModel(b.writeResp, sportStateListener, type)
    }

    fun stopSportMode() {
        b.vp.stopSportModel(b.writeResp, sportStateListener)
    }
}
