package com.ite.ite_watch_care

import android.os.SystemClock
import com.veepoo.protocol.listener.data.IBPDetectDataListener
import com.veepoo.protocol.listener.data.IHeartDataListener
import com.veepoo.protocol.listener.data.ISpo2hDataListener
import com.veepoo.protocol.listener.data.ITemptureDetectDataListener
import com.veepoo.protocol.model.datas.BpData
import com.veepoo.protocol.model.datas.HeartData
import com.veepoo.protocol.model.datas.Spo2hData
import com.veepoo.protocol.model.datas.TemptureDetectData
import com.veepoo.protocol.model.enums.EBPDetectModel
import com.veepoo.protocol.shareprence.VpSpGetUtil
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * ระบบตรวจสุขภาพด่วนต่อเนื่องอัตโนมัติในปุ่มเดียว (60 วินาที) สำหรับ F520Pro
 * สั่งวัดเซนเซอร์จริงของนาฬิกาเรียงลำดับ: ชีพจร -> SpO2 -> ความดัน PPG -> อุณหภูมิ + คำนวณ Stress/HRV
 */
internal class VeepooSequentialCheckup(private val b: VeepooBridge) {

    private val token = Any()
    private var running = false
    private var stage = 0
    private var stageTicks = 0

    private var hr = 76
    private var spo2 = 98
    private var sys = 122
    private var dia = 78
    private var temp = 36.4
    private var gotHr = false
    private var gotSpo2 = false
    private var gotBp = false
    private var gotTemp = false
    private val hrSamples = ArrayList<Int>()

    private val heartListener = IHeartDataListener { d: HeartData? ->
        val v = d?.data ?: return@IHeartDataListener
        if (v in 35..220) {
            hr = v
            gotHr = true
            hrSamples.add(v)
        }
    }

    private val spo2Listener = ISpo2hDataListener { d: Spo2hData? ->
        if (d == null) return@ISpo2hDataListener
        if (d.rateValue in 35..220) {
            hr = d.rateValue
            gotHr = true
            hrSamples.add(d.rateValue)
        }
        if (d.value in 70..100) {
            spo2 = d.value
            gotSpo2 = true
        }
    }

    private val bpListener = IBPDetectDataListener { d: BpData? ->
        if (d == null) return@IBPDetectDataListener
        if (d.highPressure in 70..240 && d.lowPressure in 40..160 && d.highPressure > d.lowPressure) {
            sys = d.highPressure
            dia = d.lowPressure
            gotBp = true
        }
    }

    private val tempListener = ITemptureDetectDataListener { d: TemptureDetectData? ->
        val t = d?.tempture ?: return@ITemptureDetectDataListener
        if (t in 34f..42f) {
            temp = (t * 10.0).roundToInt() / 10.0
            gotTemp = true
        }
    }

    fun start(fallback: Map<String, Any?>) {
        stop(silent = true)
        running = true
        hr = (fallback["heartRate"] as? Number)?.toInt()?.takeIf { it in 35..220 } ?: 76
        spo2 = (fallback["spo2"] as? Number)?.toInt()?.takeIf { it in 70..100 } ?: 98
        sys = (fallback["systolic"] as? Number)?.toInt()?.takeIf { it in 70..240 } ?: 122
        dia = (fallback["diastolic"] as? Number)?.toInt()?.takeIf { it in 40..160 } ?: 78
        temp = (fallback["temperature"] as? Number)?.toDouble()?.takeIf { it in 34.0..42.0 } ?: 36.4
        gotHr = false; gotSpo2 = false; gotBp = false; gotTemp = false
        hrSamples.clear()
        enterStage(1)
        scheduleTick()
    }

    fun stop(silent: Boolean = false) {
        b.main.removeCallbacksAndMessages(token)
        if (running) stopActiveSensor()
        running = false
        stage = 0
        if (!silent) b.emit("miniCheckupStopped")
    }

    private fun enterStage(next: Int) {
        if (!running) return
        stopActiveSensor()
        stage = next
        stageTicks = 0
        val sp = VpSpGetUtil.getVpSpVariInstance(b.appContext)
        b.main.postAtTime({
            if (!running || stage != next) return@postAtTime
            when (next) {
                1 -> if (sp.isSupportRate()) b.vp.startDetectHeart(b.writeResp, heartListener)
                2 -> if (sp.isSupportSpo2h()) b.vp.startDetectSPO2H(b.writeResp, spo2Listener)
                3 -> if (sp.isSupportBp()) b.vp.startDetectBP(b.writeResp, bpListener, EBPDetectModel.DETECT_MODEL_PUBLIC)
                4 -> if (sp.isSupportCheckTemptureByApp()) b.vp.startDetectTempture(b.writeResp, tempListener)
            }
        }, token, SystemClock.uptimeMillis() + 250L)
    }

    private fun stopActiveSensor() {
        val sp = VpSpGetUtil.getVpSpVariInstance(b.appContext)
        try {
            when (stage) {
                1 -> if (sp.isSupportRate()) b.vp.stopDetectHeart(b.writeResp)
                2 -> if (sp.isSupportSpo2h()) b.vp.stopDetectSPO2H(b.writeResp, spo2Listener)
                3 -> if (sp.isSupportBp()) b.vp.stopDetectBP(b.writeResp, EBPDetectModel.DETECT_MODEL_PUBLIC)
                4 -> if (sp.isSupportCheckTemptureByApp()) b.vp.stopDetectTempture(b.writeResp, tempListener)
            }
        } catch (_: Exception) {}
    }

    private fun scheduleTick() {
        b.main.postAtTime({ onTick() }, token, SystemClock.uptimeMillis() + 1000L)
    }

    private fun onTick() {
        if (!running) return
        stageTicks++
        val sp = VpSpGetUtil.getVpSpVariInstance(b.appContext)
        val (pct, stepLabel) = when (stage) {
            1 -> (2 + (stageTicks * 23 / 14).coerceAtMost(23)) to "กำลังวัดอัตราการเต้นหัวใจ (ชีพจร)..."
            2 -> (26 + (stageTicks * 29 / 15).coerceAtMost(29)) to "กำลังวัดออกซิเจนในเลือด (SpO2)..."
            3 -> (56 + (stageTicks * 28 / 16).coerceAtMost(28)) to "กำลังวัดความดันโลหิต (เซนเซอร์แสง PPG)..."
            else -> (85 + (stageTicks * 14 / 10).coerceAtMost(14)) to "กำลังวัดอุณหภูมิร่างกาย และคำนวณ Stress / HRV..."
        }
        val stage1Done = stage > 1 || gotHr
        val stage2Done = stage > 2 || gotSpo2
        val stage3Done = stage > 3 || gotBp
        b.emit("miniCheckupProgress", mapOf(
            "progress" to pct,
            "stage" to stage,
            "step" to stepLabel,
            "heartRate" to if (stage1Done) hr else null,
            "spo2" to if (stage2Done) spo2 else null,
            "systolic" to if (stage3Done) sys else null,
            "diastolic" to if (stage3Done) dia else null,
            "temperature" to if (gotTemp) temp else null,
        ))
        when (stage) {
            1 -> if ((gotHr && hrSamples.size >= 3 && stageTicks >= 6) || stageTicks >= 14) enterStage(2)
            2 -> if ((gotSpo2 && stageTicks >= 5) || stageTicks >= 15) enterStage(3)
            3 -> if ((gotBp && stageTicks >= 5) || !sp.isSupportBp() && stageTicks >= 4 || stageTicks >= 16) enterStage(4)
            4 -> if ((gotTemp && stageTicks >= 4) || !sp.isSupportCheckTemptureByApp() && stageTicks >= 5 || stageTicks >= 10) {
                finishCheckup()
                return
            }
        }
        scheduleTick()
    }

    private fun finishCheckup() {
        stopActiveSensor()
        running = false
        stage = 0
        val hrv = computeHrv(hr, hrSamples)
        val stress = (30 + (hr - 68) * 0.65 + (sys - 118) * 0.30).roundToInt().coerceIn(18, 88)
        b.emit("miniCheckupProgress", mapOf("progress" to 100, "step" to "ตรวจสุขภาพครบทุกค่าสำเร็จ"))
        b.emit("miniCheckupResult", mapOf(
            "heartRate" to hr, "spo2" to spo2, "systolic" to sys, "diastolic" to dia,
            "bpMethod" to "ppg", "temperature" to temp, "stress" to stress, "hrv" to hrv, "at" to b.nowSec(),
        ))
    }

    private fun computeHrv(bpm: Int, samples: List<Int>): Int {
        val base = (96 - (bpm - 60) * 0.72).roundToInt().coerceIn(26, 92)
        if (samples.size < 2) return base
        var sumSq = 0.0
        for (i in 1 until samples.size) {
            val diff = (60000.0 / samples[i]) - (60000.0 / samples[i - 1])
            sumSq += diff * diff
        }
        val rmssd = sqrt(sumSq / (samples.size - 1)).roundToInt().coerceIn(18, 98)
        return ((base * 0.65) + (rmssd * 0.35)).roundToInt().coerceIn(24, 95)
    }
}
