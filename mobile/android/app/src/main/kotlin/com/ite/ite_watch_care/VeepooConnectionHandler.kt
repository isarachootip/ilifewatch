package com.ite.ite_watch_care

import com.inuker.bluetooth.library.Constants
import com.inuker.bluetooth.library.model.BleGattProfile
import com.inuker.bluetooth.library.search.SearchResult
import com.inuker.bluetooth.library.search.response.SearchResponse
import com.veepoo.protocol.listener.base.IABleConnectStatusListener
import com.veepoo.protocol.listener.base.IConnectResponse
import com.veepoo.protocol.listener.base.INotifyResponse
import com.veepoo.protocol.listener.data.IBatteryDataListener
import com.veepoo.protocol.listener.data.ICustomSettingDataListener
import com.veepoo.protocol.listener.data.IDeviceFuctionDataListener
import com.veepoo.protocol.listener.data.IPersonInfoDataListener
import com.veepoo.protocol.listener.data.IPwdDataListener
import com.veepoo.protocol.listener.data.ISocialMsgDataListener
import com.veepoo.protocol.model.datas.BatteryData
import com.veepoo.protocol.model.datas.DeviceFunctionPackage1
import com.veepoo.protocol.model.datas.DeviceFunctionPackage2
import com.veepoo.protocol.model.datas.DeviceFunctionPackage3
import com.veepoo.protocol.model.datas.DeviceFunctionPackage4
import com.veepoo.protocol.model.datas.DeviceFunctionPackage5
import com.veepoo.protocol.model.datas.FunctionDeviceSupportData
import com.veepoo.protocol.model.datas.FunctionSocailMsgData
import com.veepoo.protocol.model.datas.PersonInfoData
import com.veepoo.protocol.model.datas.PwdData
import com.veepoo.protocol.model.enums.EFunctionStatus
import com.veepoo.protocol.model.enums.EOprateStauts
import com.veepoo.protocol.model.enums.EPwdStatus
import com.veepoo.protocol.model.enums.ESex
import com.veepoo.protocol.model.settings.CustomSettingData
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

internal class VeepooConnectionHandler(private val b: VeepooBridge) {

    @android.annotation.SuppressLint("MissingPermission")
    fun startScan() {
        try {
            android.bluetooth.BluetoothAdapter.getDefaultAdapter()?.bondedDevices?.forEach { d ->
                b.emit("scan", mapOf("name" to (d.name ?: ""), "mac" to d.address, "rssi" to -40))
            }
        } catch (_: Throwable) {}
        b.vp.startScanDevice(object : SearchResponse {
            override fun onSearchStarted() {}
            override fun onDeviceFounded(r: SearchResult?) {
                if (r == null) return
                b.emit("scan", mapOf("name" to (r.name ?: ""), "mac" to r.address, "rssi" to r.rssi))
            }
            override fun onSearchStopped() {}
            override fun onSearchCanceled() {}
        })
    }

    fun connect(mac: String, deviceName: String = "F520Pro") {
        b.vp.stopScanDevice()
        b.currentMac = mac
        b.currentDeviceName = deviceName
        b.emit("connection", mapOf("state" to "connecting"))
        b.vp.registerConnectStatusListener(mac, object : IABleConnectStatusListener() {
            override fun onConnectStatusChanged(address: String?, status: Int) {
                if (status == Constants.STATUS_DISCONNECTED) {
                    b.emit("connection", mapOf("state" to "disconnected"))
                }
            }
        })
        b.vp.connectDevice(mac, deviceName, object : IConnectResponse {
            override fun connectState(code: Int, profile: BleGattProfile?, isOadModel: Boolean) {
                if (code == Constants.REQUEST_SUCCESS) {
                    b.emit("connection", mapOf("state" to "connected"))
                } else {
                    b.emit("connection", mapOf("state" to "failed", "detail" to "connect code=$code"))
                }
            }
        }, object : INotifyResponse {
            override fun notifyState(state: Int) {
                // ต้องรอ notify สำเร็จก่อนจึงยืนยันรหัสผ่านได้
                if (state == Constants.REQUEST_SUCCESS) confirmPassword()
                else b.emit("connection", mapOf("state" to "failed", "detail" to "notify state=$state"))
            }
        })
    }

    private fun confirmPassword() {
        b.vp.confirmDevicePwd(b.writeResp, object : IPwdDataListener {
            override fun onPwdDataChange(pwd: PwdData?) {
                val s = pwd?.getmStatus()
                if (s == EPwdStatus.CHECK_SUCCESS || s == EPwdStatus.CHECK_AND_TIME_SUCCESS) {
                    b.emit("connection", mapOf("state" to "ready"))
                    b.emit("deviceInfo", mapOf(
                        "mac" to b.currentMac,
                        "firmware" to pwd?.deviceVersion,
                        "deviceNumber" to pwd?.deviceNumber,
                    ))
                } else if (s == EPwdStatus.CHECK_FAIL) {
                    b.emit("connection", mapOf("state" to "failed", "detail" to "password"))
                }
            }
            override fun onConnectionConfirmTimeout() {
                b.emit("connection", mapOf("state" to "failed", "detail" to "confirm timeout"))
            }
        }, object : IDeviceFuctionDataListener {
            override fun onFunctionSupportDataChange(f: FunctionDeviceSupportData?) {
                if (f == null) return
                if (f.wathcDay > 0) b.watchDays = f.wathcDay
                if (f.originProtcolVersion > 0) b.originProtocolVersion = f.originProtcolVersion
                b.isSleepPrecision = isSupported(f.precisionSleep)
                b.emit("capabilities", mapOf(
                    "bp" to isSupported(f.bp),
                    "ecg" to isSupported(f.ecg),
                    "spo2" to isSupported(f.spo2H),
                    "temperature" to isSupported(f.temperatureFunction),
                    "watchDays" to b.watchDays,
                    "originProtocolVersion" to b.originProtocolVersion,
                    "sleepPrecision" to b.isSleepPrecision,
                ))
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
        val info = PersonInfoData(
            sex,
            call.argument<Int>("heightCm") ?: 160,
            call.argument<Int>("weightKg") ?: 60,
            call.argument<Int>("age") ?: 60,
            call.argument<Int>("stepGoal") ?: 6000,
        )
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
                if (bat == null) return
                b.emit("battery", mapOf(
                    "isPercent" to bat.isPercent,
                    "percent" to if (bat.isPercent) bat.batteryPercent else null,
                    "level" to bat.batteryLevel,
                    "low" to bat.isLowBattery,
                ))
            }
        })
    }
}
