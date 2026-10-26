package com.ite.ite_watch_care

import com.veepoo.protocol.listener.IMiniCheckupOptListener
import com.veepoo.protocol.listener.data.IAutoMeasureSettingDataListener
import com.veepoo.protocol.listener.data.ICustomSettingDataListener
import com.veepoo.protocol.model.datas.AutoMeasureData
import com.veepoo.protocol.model.datas.MiniCheckupDetailData
import com.veepoo.protocol.model.datas.MiniCheckupResultData
import com.veepoo.protocol.model.enums.EFunctionStatus
import com.veepoo.protocol.model.enums.EMiniCheckupTestErrorCode
import com.veepoo.protocol.model.settings.CustomSetting
import com.veepoo.protocol.model.settings.CustomSettingData

/**
 * จัดการฟีเจอร์ใหม่จาก Joeme Fit SDK 260626_new:
 * 1) One-Tap Mini Checkup (ตรวจสุขภาพด่วนในปุ่มเดียว 60 วินาที: ชีพจร, ความดัน, SpO2, อุณหภูมิ, ความเครียด, HRV)
 * 2) เปิดโหมดวัดอัตโนมัติ 24 ชม. บนตัวนาฬิกา (Auto HR, Auto BP, Auto Temp, Auto HRV, Auto Stress)
 */
internal class VeepooMiniCheckupHandler(private val b: VeepooBridge) {

    private val checkupListener = object : IMiniCheckupOptListener {
        override fun onMiniCheckupTestProgress(progress: Int) {
            b.emit("miniCheckupProgress", mapOf("progress" to progress))
        }

        override fun onMiniCheckupStopSuccess() {
            b.emit("miniCheckupStopped")
        }

        override fun onMiniCheckupTestFailed(errorCode: EMiniCheckupTestErrorCode) {
            b.emit("miniCheckupError", mapOf("status" to errorCode.name))
        }

        override fun onMiniCheckupSuccess(r: MiniCheckupResultData) {
            b.emit("miniCheckupResult", mapOf(
                "heartRate" to r.heartRate,
                "spo2" to r.bloodOxygen,
                "systolic" to r.systolicBloodPressure,
                "diastolic" to r.diastolicBloodPressure,
                "temperature" to if (r.bodyTemperature in 30f..45f) r.bodyTemperature.toDouble() else null,
                "stress" to r.stress,
                "hrv" to r.hrv,
                "fatigue" to r.fatigue,
                "bloodGlucose" to if (r.bloodGlucose > 0f) r.bloodGlucose.toDouble() else null,
                "at" to b.nowSec(),
            ))
        }

        override fun onMiniCheckupDetailTestSuccess(d: MiniCheckupDetailData) {
            val sys = d.bpAirPump?.systolicBloodPressure?.takeIf { it > 0 }
                ?: d.bpPhotoelectric?.systolicBloodPressure ?: 0
            val dia = d.bpAirPump?.diastolicBloodPressure?.takeIf { it > 0 }
                ?: d.bpPhotoelectric?.diastolicBloodPressure ?: 0
            val method = if ((d.bpAirPump?.systolicBloodPressure ?: 0) > 0) "cuff" else "ppg"
            val temp = d.bodyTemperature.takeIf { it in 30f..45f }?.toDouble()
            b.emit("miniCheckupResult", mapOf(
                "heartRate" to d.heartRate,
                "spo2" to d.bloodOxygen,
                "systolic" to sys,
                "diastolic" to dia,
                "bpMethod" to method,
                "temperature" to temp,
                "stress" to d.stress,
                "hrv" to d.hrv,
                "fatigue" to d.fatigue,
                "bloodGlucose" to if (d.bloodGlucose > 0f) d.bloodGlucose.toDouble() else null,
                "at" to b.nowSec(),
            ))
        }
    }

    fun startMiniCheckup() {
        b.vp.startMiniCheckup(b.writeResp, checkupListener)
    }

    fun stopMiniCheckup() {
        b.vp.stopMiniCheckup(b.writeResp, checkupListener)
    }

    /**
     * สั่งเปิดโหมดวัดอัตโนมัติบนตัวนาฬิกา (Auto HR, Auto BP, Auto Temp, Auto HRV, Auto Stress)
     * เพื่อให้มีกราฟ 24 ชม. เสมอโดยที่ผู้ใช้ไม่ต้องกดเปิดเอง
     */
    fun enableAutoDetect() {
        val setting = CustomSetting(true, true, true, true, true).apply {
            isOpenAutoHRV = EFunctionStatus.SUPPORT_OPEN
            isOpenAutoTemperatureDetect = EFunctionStatus.SUPPORT_OPEN
            stressDetect = EFunctionStatus.SUPPORT_OPEN
        }
        b.vp.changeCustomSetting(b.writeResp, object : ICustomSettingDataListener {
            override fun OnSettingDataChange(d: CustomSettingData?) {
                enableV2AutoMeasureItems()
            }
        }, setting)
    }

    private fun enableV2AutoMeasureItems() {
        b.vp.readAutoMeasureSettingData(b.writeResp, object : IAutoMeasureSettingDataListener {
            override fun onSettingDataChange(list: MutableList<AutoMeasureData>?) {
                val pending = list?.filter { !it.isSwitchOpen } ?: return
                for (item in pending) {
                    item.isSwitchOpen = true
                    b.vp.setAutoMeasureSettingData(b.writeResp, item, object : IAutoMeasureSettingDataListener {
                        override fun onSettingDataChange(l: MutableList<AutoMeasureData>?) {}
                        override fun onSettingDataChangeSuccess() {}
                        override fun onSettingDataChangeFail() {}
                    })
                }
            }
            override fun onSettingDataChangeSuccess() {}
            override fun onSettingDataChangeFail() {}
        })
    }
}
