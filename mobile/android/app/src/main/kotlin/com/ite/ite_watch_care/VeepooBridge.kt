package com.ite.ite_watch_care

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.inuker.bluetooth.library.Constants
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.model.datas.TimeData
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

/**
 * ตัวเชื่อม Flutter <-> Veepoo Android SDK (vpprotocol 2.3.68.15)
 *
 * ลำดับการเชื่อมต่อตาม README ของ SDK:
 *   connectDevice -> (notifyState == REQUEST_SUCCESS) -> confirmDevicePwd -> syncPersonInfo
 * นาฬิกาไม่รองรับคำสั่งพร้อมกัน ฝั่ง Dart (WatchService) มีคิวคุมให้ทำทีละคำสั่ง
 */
class VeepooBridge(context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        internal const val TAG = "VeepooBridge"
        internal const val DEFAULT_WATCH_DAYS = 3
    }

    internal val vp: VPOperateManager = VPOperateManager.getInstance().also {
        it.init(context.applicationContext)
        it.setDeviceShowConfirm(true)
    }
    internal val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    internal var currentMac: String? = null
    internal var currentDeviceName: String = "F520Pro"
    internal var password: String = "0000"
    internal var watchDays = DEFAULT_WATCH_DAYS
    internal var originProtocolVersion: Int = 3
    internal var isSleepPrecision: Boolean = false

    private val connectionHandler = VeepooConnectionHandler(this)
    private val measureHandler = VeepooMeasureHandler(this)
    private val liveVitalHandler = VeepooLiveVitalHandler(this)
    private val syncHandler = VeepooSyncHandler(this)
    private val manualReader = VeepooManualReader(this)
    private val miniCheckupHandler = VeepooMiniCheckupHandler(this)

    init {
        MethodChannel(messenger, "ite.watch/method").setMethodCallHandler(this)
        EventChannel(messenger, "ite.watch/events").setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    internal fun emit(type: String, data: Map<String, Any?> = emptyMap()) {
        val m = HashMap<String, Any?>(data)
        m["type"] = type
        main.post { sink?.success(m) }
    }

    internal val writeResp = object : IBleWriteResponse {
        override fun onResponse(code: Int) {
            if (code != Constants.REQUEST_SUCCESS) Log.w(TAG, "write failed code=$code")
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "startScan" -> {
                    connectionHandler.startScan()
                    result.success(null)
                }
                "stopScan" -> {
                    vp.stopScanDevice()
                    result.success(null)
                }
                "connect" -> {
                    password = call.argument<String>("password") ?: "0000"
                    val name = call.argument<String>("name")?.takeIf { it.isNotBlank() } ?: "F520Pro"
                    connectionHandler.connect(call.argument<String>("mac")!!, name)
                    result.success(null)
                }
                "disconnect" -> {
                    vp.disconnectWatch(writeResp)
                    result.success(null)
                }
                "syncProfile" -> connectionHandler.syncProfile(call, result)
                "readBattery" -> {
                    connectionHandler.readBattery()
                    result.success(null)
                }
                "startBp" -> {
                    measureHandler.startBp(call.argument<String>("method") ?: "cuff")
                    result.success(null)
                }
                "stopBp" -> {
                    measureHandler.stopBp(call.argument<String>("method") ?: "cuff")
                    result.success(null)
                }
                "startEcg" -> {
                    measureHandler.startEcg()
                    result.success(null)
                }
                "stopEcg" -> {
                    measureHandler.stopEcg()
                    result.success(null)
                }
                "startSpo2" -> {
                    liveVitalHandler.startSpo2()
                    result.success(null)
                }
                "stopSpo2" -> {
                    liveVitalHandler.stopSpo2()
                    result.success(null)
                }
                "startTemp" -> {
                    liveVitalHandler.startTemp()
                    result.success(null)
                }
                "stopTemp" -> {
                    liveVitalHandler.stopTemp()
                    result.success(null)
                }
                "startHeart" -> {
                    liveVitalHandler.startHeart()
                    result.success(null)
                }
                "stopHeart" -> {
                    liveVitalHandler.stopHeart()
                    result.success(null)
                }
                "readSportStep" -> {
                    liveVitalHandler.readSportStep()
                    result.success(null)
                }
                "startSportMode" -> {
                    liveVitalHandler.startSportMode(call.argument<String>("mode") ?: "walk")
                    result.success(null)
                }
                "stopSportMode" -> {
                    liveVitalHandler.stopSportMode()
                    result.success(null)
                }
                "syncHistory" -> {
                    syncHandler.syncHistory()
                    result.success(null)
                }
                "readWatchMeasurements" -> {
                    val since = (call.argument<Number>("since") ?: 0).toLong()
                    manualReader.readManual(since)
                    result.success(null)
                }
                "startMiniCheckup" -> {
                    miniCheckupHandler.startMiniCheckup()
                    result.success(null)
                }
                "stopMiniCheckup" -> {
                    miniCheckupHandler.stopMiniCheckup()
                    result.success(null)
                }
                "enableAutoDetect" -> {
                    miniCheckupHandler.enableAutoDetect()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e(TAG, "call ${call.method} failed", e)
            result.error("NATIVE_ERROR", e.message, null)
        }
    }

    internal fun sample(at: Long, metric: String, value: Double) =
        mapOf("at" to at, "metric" to metric, "value" to value)

    internal fun nowSec() = System.currentTimeMillis() / 1000

    internal fun toEpochSec(t: TimeData): Long {
        val c = Calendar.getInstance()
        c.set(t.year, t.month - 1, t.day, t.hour, t.minute, t.second)
        c.set(Calendar.MILLISECOND, 0)
        return c.timeInMillis / 1000
    }
}
