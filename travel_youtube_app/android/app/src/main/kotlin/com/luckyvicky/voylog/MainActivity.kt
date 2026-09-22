package com.luckyvicky.voylog

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createDefaultNotificationChannel()
    }

    /**
     * FR-12: the channel AndroidManifest names as FCM's default. Without it
     * Android drops every push into its own "Miscellaneous" fallback channel,
     * which the user can only find under that name in system settings.
     * Channels are per-app and only exist from Android 8 (API 26).
     */
    private fun createDefaultNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            DEFAULT_CHANNEL_ID,
            "여행 알림",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "영상 분석 완료, 여행 시작 알림을 받아요"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        // Must match the default_notification_channel_id meta-data in
        // AndroidManifest.xml -- FCM reads the channel by that id.
        private const val DEFAULT_CHANNEL_ID = "voylog_default"
    }
}
