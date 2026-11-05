package com.ite.ite_watch_care

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import com.inuker.bluetooth.library.search.SearchResult
import com.inuker.bluetooth.library.search.response.SearchResponse
import com.veepoo.protocol.util.VpBleByteUtil

/**
 * Dual-Engine BLE Watch Scanner สำหรับค้นหานาฬิกา F520Pro / Veepoo โดยเฉพาะ:
 * 1) สแกนตรงด้วย Android BluetoothLeScanner (SCAN_MODE_LOW_LATENCY) เพื่อแก้บั๊ก ScanSettings ใน vpbluetooth-1.20
 * 2) สแกนควบคู่กับ VPOperateManager.startScanDevice
 * 3) ดึงอุปกรณ์ที่ต่อค้างในระบบ GATT (กรณีนาฬิกาเชื่อมต่อค้างอยู่และหยุดปล่อย Advertisement)
 * 4) คัดกรองเฉพาะนาฬิกาตระกูล F520Pro / Veepoo เท่านั้น (ตัดหูฟัง/เครื่องเสียงรถยนต์ออก 100%)
 */
@SuppressLint("MissingPermission")
internal class VeepooWatchScanner(private val b: VeepooBridge) {

    companion object {
        private val WATCH_KEYWORDS = listOf(
            "F520", "ILIFE", "VEEPOO", "JOEME", "HBAND", "H BAND", "WATCH", "E500", "E400", "ET5", "ET4", "G08", "RIG"
        )
        private val BLOCKED_KEYWORDS = listOf(
            "CAR MULTIMEDIA", "SHOKZ", "OPENDOTS", "AIRPODS", "BUDS", "SPEAKER", "HANDSFREE", "AUDIO", "TV", "IDEA"
        )
        private val WATCH_SERVICE_PREFIXES = listOf("0000fee7", "0000ffff", "0000180d", "0000f800", "0000ae00")
    }

    private var leCallback: ScanCallback? = null

    fun startScan() {
        stopScan()
        emitConnectedAndBondedWatches()
        startNativeLowLatencyScan()
        b.vp.startScanDevice(object : SearchResponse {
            override fun onSearchStarted() {}
            override fun onDeviceFounded(r: SearchResult?) {
                if (r == null) return
                val name = r.name?.takeIf { it.isNotBlank() && it != "NULL" } ?: "F520Pro"
                if (isBlockedName(name)) return
                b.emit("scan", mapOf("name" to name, "mac" to r.address, "rssi" to r.rssi, "isVp" to true))
            }
            override fun onSearchStopped() {}
            override fun onSearchCanceled() {}
        })
    }

    private fun btManager(): BluetoothManager? =
        b.appContext.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager

    private fun btAdapter(): BluetoothAdapter? = btManager()?.adapter

    fun stopScan() {
        try {
            leCallback?.let { cb -> btAdapter()?.bluetoothLeScanner?.stopScan(cb) }
        } catch (_: Throwable) {}
        leCallback = null
        try { b.vp.stopScanDevice() } catch (_: Throwable) {}
    }

    private fun emitConnectedAndBondedWatches() {
        try {
            btManager()?.getConnectedDevices(BluetoothProfile.GATT)?.forEach { d ->
                if (isAllowedStoredWatch(d)) {
                    b.emit("scan", mapOf("name" to (d.name ?: "F520Pro"), "mac" to d.address, "rssi" to -48, "isVp" to true))
                }
            }
            btAdapter()?.bondedDevices?.forEach { d ->
                if (isAllowedStoredWatch(d)) {
                    b.emit("scan", mapOf("name" to (d.name ?: "F520Pro"), "mac" to d.address, "rssi" to -65, "isVp" to true))
                }
            }
        } catch (_: Throwable) {}
    }

    private fun startNativeLowLatencyScan() {
        try {
            val scanner = btAdapter()?.bluetoothLeScanner ?: return
            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .setReportDelay(0)
                .apply { if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) setLegacy(true) }
                .build()
            val cb = object : ScanCallback() {
                override fun onScanResult(callbackType: Int, result: ScanResult?) {
                    result?.let { handleNativeScanResult(it) }
                }
                override fun onBatchScanResults(results: MutableList<ScanResult>?) {
                    results?.forEach { handleNativeScanResult(it) }
                }
            }
            leCallback = cb
            scanner.startScan(null, settings, cb)
        } catch (_: Throwable) {}
    }

    private fun handleNativeScanResult(res: ScanResult) {
        val device = res.device ?: return
        if (isNonWatchBluetoothClass(device)) return
        val rawName = (device.name ?: res.scanRecord?.deviceName ?: "").trim()
        if (isBlockedName(rawName)) return
        val bytes = res.scanRecord?.bytes
        val isVp = isVpPayload(bytes, res)
        val hasWatchName = isWatchName(rawName)
        if (!isVp && !hasWatchName) return
        val displayName = if (rawName.isNotEmpty()) rawName else "F520Pro"
        b.emit("scan", mapOf("name" to displayName, "mac" to device.address, "rssi" to res.rssi, "isVp" to true))
    }

    private fun isVpPayload(bytes: ByteArray?, res: ScanResult): Boolean {
        if (bytes != null) {
            try {
                if (VpBleByteUtil.isBeyondVp(bytes) || VpBleByteUtil.isBeyondVpV2(bytes) || b.vp.isVPDevice(bytes)) {
                    return true
                }
            } catch (_: Throwable) {}
        }
        val uuids = res.scanRecord?.serviceUuids ?: return false
        return uuids.any { u -> WATCH_SERVICE_PREFIXES.any { p -> u.uuid.toString().lowercase().startsWith(p) } }
    }

    private fun isAllowedStoredWatch(d: BluetoothDevice): Boolean {
        if (isNonWatchBluetoothClass(d)) return false
        if (d.type == BluetoothDevice.DEVICE_TYPE_CLASSIC) return false
        val name = (d.name ?: "").trim()
        if (name.isEmpty() || isBlockedName(name)) return false
        return isWatchName(name) || (b.currentMac != null && d.address.equals(b.currentMac, ignoreCase = true))
    }

    private fun isNonWatchBluetoothClass(d: BluetoothDevice): Boolean {
        return try {
            when (d.bluetoothClass?.majorDeviceClass) {
                BluetoothClass.Device.Major.AUDIO_VIDEO,
                BluetoothClass.Device.Major.COMPUTER,
                BluetoothClass.Device.Major.PHONE,
                BluetoothClass.Device.Major.IMAGING,
                BluetoothClass.Device.Major.PERIPHERAL,
                BluetoothClass.Device.Major.NETWORKING -> true
                else -> false
            }
        } catch (_: Throwable) { false }
    }

    private fun isWatchName(name: String): Boolean {
        val upper = name.uppercase()
        return WATCH_KEYWORDS.any { upper.contains(it) }
    }

    private fun isBlockedName(name: String): Boolean {
        val upper = name.uppercase()
        return BLOCKED_KEYWORDS.any { upper.contains(it) }
    }
}
