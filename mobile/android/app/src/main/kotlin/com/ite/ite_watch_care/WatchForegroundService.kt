package com.ite.ite_watch_care

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

/**
 * บริการเบื้องหลัง (Foreground Service) สำหรับรักษาการเชื่อมต่อ BLE กับนาฬิกา F520Pro ตลอด 24 ชม.
 * แม้โทรศัพท์จะล็อกหน้าจอเป็นเวลานาน
 */
class WatchForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "ilife_watch_guard"
        private const val NOTIF_ID = 5201

        fun setRunning(context: Context, enabled: Boolean) {
            val intent = Intent(context, WatchForegroundService::class.java)
            try {
                if (enabled) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(intent)
                    } else {
                        context.startService(intent)
                    }
                } else {
                    context.stopService(intent)
                }
            } catch (_: Throwable) {}
        }
    }

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIF_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIF_ID, buildNotification())
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(
                CHANNEL_ID,
                "iLife Watch 24/7 Care",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "รักษาการเชื่อมต่อนาฬิกา F520Pro เพื่อซิงค์ข้อมูลสุขภาพ 24 ชม."
                setShowBadge(false)
            }
            mgr.createNotificationChannel(ch)
        }
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pending = if (launchIntent != null) {
            PendingIntent.getActivity(
                this,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        } else null

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("iLife Watch กำลังดูแลสุขภาพ 24 ชม.")
            .setContentText("เชื่อมต่อและซิงค์ข้อมูลจากนาฬิกา F520Pro อัตโนมัติ")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setContentIntent(pending)
            .build()
    }
}
