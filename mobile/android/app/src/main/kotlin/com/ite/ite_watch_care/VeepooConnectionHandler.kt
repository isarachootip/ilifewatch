package com.ite.ite_watch_care

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGattCallback
import android.os.SystemClock
import com.inuker.bluetooth.library.BluetoothClient
import com.inuker.bluetooth.library.Constants
import com.inuker.bluetooth.library.model.BleGattProfile
import com.inuker.bluetooth.library.utils.BluetoothUtils
import com.veepoo.protocol.listener.base.IABleConnectStatusListener
import com.veepoo.protocol.listener.base.IConnectResponse
import com.veepoo.protocol.listener.base.INotifyResponse
import com.veepoo.protocol.listener.data.*
import com.veepoo.protocol.model.datas.*
import com.veepoo.protocol.model.enums.*
import com.veepoo.protocol.model.settings.CustomSettingData
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

@SuppressLint("MissingPermission")
internal class VeepooConnectionHandler(private val b: VeepooBridge) {

    private val scanner = VeepooWatchScanner(b)
    private val bleClient = BluetoothClient(b.appContext)
    private val connectToken = Any()
    private var connectGen = 0
    private var isReady = false

    fun startScan() = scanner.startScan()
    fun stopScan() = scanner.stopScan()

    fun disconnect() {
        connectGen++
        isReady = false
        b.main.removeCallbacksAndMessages(connectToken)
        forceResetGatt(b.currentMac)
        b.emit("connection", mapOf("state" to "disconnected"))
    }

    private fun forceResetGatt(mac: String?): Boolean {
        if (mac.isNullOrBlank()) return false
        var hadActive = false
        try {
            bleClient.clearRequest(mac, 0)
            val gatt = bleClient.getGatt(mac)
            val status = bleClient.getConnectStatus(mac)
            if (gatt != null) {
                hadActive = true
                runCatching { BluetoothUtils.refreshGattCache(gatt) }
                runCatching { gatt.disconnect() }
            }
            if (status != Constants.STATUS_DEVICE_DISCONNECTED) hadActive = true
            bleClient.disconnect(mac)
            if (gatt == null && status == Constants.STATUS_DEVICE_CONNECTED) {
                val tmp = BluetoothUtils.getRemoteDevice(mac)?.connectGatt(b.appContext, false, object : BluetoothGattCallback() {}, BluetoothDevice.TRANSPORT_LE)
                runCatching { tmp?.disconnect() }
                runCatching { tmp?.close() }
            }
        } catch (_: Throwable) {}
        return hadActive
    }

    fun connect(mac: String, deviceName: String = "F520Pro", attempt: Int = 0) {
        scanner.stopScan()
        val gen = ++connectGen
        isReady = false
        b.main.removeCallbacksAndMessages(connectToken)
        val prevMac = b.currentMac
        val hadPrev = if (prevMac != null && prevMac != mac) forceResetGatt(prevMac) else false
        val hadCurr = forceResetGatt(mac)
        val delayMs = if (hadPrev || hadCurr || attempt > 0) 500L else 150L

        b.currentMac = mac
        b.currentDeviceName = deviceName
        b.emit("connection", mapOf("state" to "connecting"))

        b.vp.registerConnectStatusListener(mac, object : IABleConnectStatusListener() {
            override fun onConnectStatusChanged(address: String?, status: Int) {
                if (status == Constants.STATUS_DISCONNECTED && isReady) {
                    isReady = false
                    forceResetGatt(address ?: mac)
                    b.emit("connection", mapOf("state" to "disconnected"))
                }
            }
        })

        // Watchdog ป้องกันค้างที่ขั้นตอน 1/3 หรือ 2/3 เกิน 10 วินาทีต่อรอบ
        b.main.postAtTime({
            if (gen != connectGen || isReady) return@postAtTime
            forceResetGatt(mac)
            if (attempt < 2) connect(mac, deviceName, attempt + 1)
            else b.emit("connection", mapOf("state" to "failed", "detail" to "watchdog timeout"))
        }, connectToken, SystemClock.uptimeMillis() + delayMs + 10000L)

        b.main.postAtTime({
            if (gen != connectGen) return@postAtTime
            if (bleClient.getConnectStatus(mac) == Constants.STATUS_DEVICE_CONNECTED) forceResetGatt(mac)
            b.vp.connectDevice(mac, deviceName, object : IConnectResponse {
                override fun connectState(code: Int, profile: BleGattProfile?, isOadModel: Boolean) {
                    if (gen != connectGen) return
                    if (code == Constants.REQUEST_SUCCESS) b.emit("connection", mapOf("state" to "connected"))
                    else retryOrFail(gen, mac, deviceName, attempt, "connect code=$code")
                }
            }, object : INotifyResponse {
                override fun notifyState(state: Int) {
                    if (gen != connectGen) return
                    if (state == Constants.REQUEST_SUCCESS) {
                        b.main.postAtTime({ if (gen == connectGen) confirmPassword(gen, mac, deviceName, attempt) }, connectToken, SystemClock.uptimeMillis() + 200L)
                    } else retryOrFail(gen, mac, deviceName, attempt, "notify state=$state")
                }
            })
        }, connectToken, SystemClock.uptimeMillis() + delayMs)
    }

    private fun retryOrFail(gen: Int, mac: String, deviceName: String, attempt: Int, detail: String) {
        if (gen != connectGen || isReady) return
        b.main.removeCallbacksAndMessages(connectToken)
        forceResetGatt(mac)
        if (attempt < 2) b.main.postAtTime({ connect(mac, deviceName, attempt + 1) }, connectToken, SystemClock.uptimeMillis() + 450L)
        else b.emit("connection", mapOf("state" to "failed", "detail" to detail))
    }

    private fun confirmPassword(gen: Int, mac: String, deviceName: String, attempt: Int) {
        b.vp.confirmDevicePwd(b.writeResp, object : IPwdDataListener {
            override fun onPwdDataChange(pwd: PwdData?) {
                if (gen != connectGen) return
                val s = pwd?.getmStatus()
                if (s == EPwdStatus.CHECK_SUCCESS || s == EPwdStatus.CHECK_AND_TIME_SUCCESS) {
                    isReady = true
                    b.main.removeCallbacksAndMessages(connectToken)
                    b.emit("connection", mapOf("state" to "ready"))
                    b.emit("deviceInfo", mapOf("mac" to b.currentMac, "firmware" to pwd?.deviceVersion, "deviceNumber" to pwd?.deviceNumber))
                } else if (s == EPwdStatus.CHECK_FAIL) retryOrFail(gen, mac, deviceName, attempt, "password")
            }
            override fun onConnectionConfirmTimeout() = retryOrFail(gen, mac, deviceName, attempt, "confirm timeout")
        }, object : IDeviceFuctionDataListener {
            override fun onFunctionSupportDataChange(f: FunctionDeviceSupportData?) {
                if (f == null) return
                if (f.wathcDay > 0) b.watchDays = f.wathcDay
                if (f.originProtcolVersion > 0) b.originProtocolVersion = f.originProtcolVersion
                b.isSleepPrecision = isSupported(f.precisionSleep)
                b.emit("capabilities", mapOf("bp" to isSupported(f.bp), "ecg" to isSupported(f.ecg), "spo2" to isSupported(f.spo2H), "temperature" to isSupported(f.temperatureFunction), "watchDays" to b.watchDays, "originProtocolVersion" to b.originProtocolVersion, "sleepPrecision" to b.isSleepPrecision))
            }
            override fun onDeviceFunctionPackage1Report(p: DeviceFunctionPackage1?) {}
            override fun onDeviceFunctionPackage2Report(p: DeviceFunctionPackage2?) {}
            override fun onDeviceFunctionPackage3Report(p: DeviceFunctionPackage3?) {}
            override fun onDeviceFunctionPackage4Report(p: DeviceFunctionPackage4?) {}
            override fun onDeviceFunctionPackage5Report(p: DeviceFunctionPackage5?) {}
        }, object : ISocialMsgDataListener {
            override fun onSocialMsgSupportDataChange(d: FunctionSocailMsgData?) {}
            override fun onSocialMsgSupportDataChange2(d: FunctionSocailMsgData?) {}
        }, object : ICustomSettingDataListener {
            override fun OnSettingDataChange(d: CustomSettingData?) {}
        }, b.password, true)
    }

    private fun isSupported(s: EFunctionStatus?) =
        s == EFunctionStatus.SUPPORT || s == EFunctionStatus.SUPPORT_OPEN || s == EFunctionStatus.SUPPORT_CLOSE

    fun syncProfile(call: MethodCall, result: MethodChannel.Result) {
        val sex = if (call.argument<Boolean>("isMale") == true) ESex.MAN else ESex.WOMEN
        val info = PersonInfoData(sex, call.argument<Int>("heightCm") ?: 160, call.argument<Int>("weightKg") ?: 60, call.argument<Int>("age") ?: 60, call.argument<Int>("stepGoal") ?: 6000)
        val replied = AtomicBoolean(false)
        b.vp.syncPersonInfo(b.writeResp, object : IPersonInfoDataListener {
            override fun OnPersoninfoDataChange(status: EOprateStauts?) {
                if (!replied.compareAndSet(false, true)) return
                b.main.post {
                    if (status == EOprateStauts.OPRATE_SUCCESS) result.success(null)
                    else result.error("PROFILE_FAILED", "sync person info: $status", null)
                }
            }
        }, info)
    }

    fun readBattery() {
        b.vp.readBattery(b.writeResp, object : IBatteryDataListener {
            override fun onDataChange(bat: BatteryData?) {
                if (bat != null) b.emit("battery", mapOf("isPercent" to bat.isPercent, "percent" to if (bat.isPercent) bat.batteryPercent else null, "level" to bat.batteryLevel, "low" to bat.isLowBattery))
            }
        })
    }
}
