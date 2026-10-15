package com.pifit.app

import android.Manifest
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Health Connect's Activity Result permission contract requires ComponentActivity.
class MainActivity : FlutterFragmentActivity() {
    private var activityRecognitionResult: MethodChannel.Result? = null
    private val activityRecognitionRequestCode = 7302

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.pifit.app/health")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasActivityRecognition" -> result.success(hasActivityRecognition())
                    "requestActivityRecognition" -> {
                        if (hasActivityRecognition()) {
                            result.success(true)
                        } else if (activityRecognitionResult != null) {
                            result.error("REQUEST_IN_PROGRESS", "A permission request is already open.", null)
                        } else {
                            activityRecognitionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
                                activityRecognitionRequestCode
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasActivityRecognition(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACTIVITY_RECOGNITION) ==
                PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == activityRecognitionRequestCode) {
            activityRecognitionResult?.success(hasActivityRecognition())
            activityRecognitionResult = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showHealthPrivacyIfNeeded(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        showHealthPrivacyIfNeeded(intent)
    }

    private fun showHealthPrivacyIfNeeded(intent: Intent?) {
        val action = intent?.action
        if (action != "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" &&
            action != "android.intent.action.VIEW_PERMISSION_USAGE") return
        window.decorView.post {
            if (!isFinishing && !isDestroyed) {
                AlertDialog.Builder(this)
                    .setTitle("Pi Fit · health data privacy")
                    .setMessage(
                        "Pi Fit requests read access to steps, active energy, workouts, heart rate, height and weight only when you tap Connect. " +
                        "Readings are displayed locally. Raw heart rate, activity and workout records are not sent to your account or AI coach, and do not change your score or streak. " +
                        "A body measurement is saved to your Pi Fit profile only if you explicitly select and import it; imported profile measurements follow your account backup and AI-sharing settings. " +
                        "This Android integration does not write or export records to Health Connect. " +
                        "Change or revoke access in Health Connect under App permissions → Pi Fit."
                    )
                    .setPositiveButton("Got it", null)
                    .show()
            }
        }
    }
}
