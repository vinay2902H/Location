package com.locationsharing.sender.sender_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.locationsharing.sender/location_service"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLocationService" -> {
                    val url = call.argument<String>("backend_url") ?: LocationForegroundService.DEFAULT_URL
                    val intervalSec = (call.argument<Number>("interval_seconds")?.toLong()) ?: LocationForegroundService.DEFAULT_INTERVAL_SECONDS
                    val username = call.argument<String>("username")
                    val email = call.argument<String>("email")
                    val password = call.argument<String>("password")

                    val prefs = getSharedPreferences(LocationForegroundService.PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit().apply {
                        if (!username.isNullOrBlank()) {
                            putString(LocationForegroundService.KEY_USERNAME, username)
                            putString("flutter.sender_username", username)
                            putString("flutter.winzo_current_username", username)
                        }
                        if (email != null) {
                            putString(LocationForegroundService.KEY_EMAIL, email)
                            putString("flutter.sender_email", email)
                            putString("flutter.winzo_current_email", email)
                        }
                        if (password != null) {
                            putString(LocationForegroundService.KEY_PASSWORD, password)
                            putString("flutter.sender_password", password)
                            putString("flutter.winzo_current_password", password)
                        }
                        apply()
                    }

                    val intent = Intent(this, LocationForegroundService::class.java).apply {
                        action = LocationForegroundService.ACTION_START
                        putExtra("backend_url", url)
                        putExtra("interval_seconds", intervalSec)
                        if (!username.isNullOrBlank()) putExtra("username", username)
                        if (email != null) putExtra("email", email)
                        if (password != null) putExtra("password", password)
                    }

                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }

                "updateUserCredentials" -> {
                    val username = call.argument<String>("username")
                    val email = call.argument<String>("email")
                    val password = call.argument<String>("password")

                    val prefs = getSharedPreferences(LocationForegroundService.PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit().apply {
                        if (!username.isNullOrBlank()) {
                            putString(LocationForegroundService.KEY_USERNAME, username)
                            putString("flutter.sender_username", username)
                            putString("flutter.winzo_current_username", username)
                        }
                        if (email != null) {
                            putString(LocationForegroundService.KEY_EMAIL, email)
                            putString("flutter.sender_email", email)
                            putString("flutter.winzo_current_email", email)
                        }
                        if (password != null) {
                            putString(LocationForegroundService.KEY_PASSWORD, password)
                            putString("flutter.sender_password", password)
                            putString("flutter.winzo_current_password", password)
                        }
                        apply()
                    }

                    val intent = Intent(this, LocationForegroundService::class.java).apply {
                        action = LocationForegroundService.ACTION_UPDATE_CREDENTIALS
                        if (!username.isNullOrBlank()) putExtra("username", username)
                        if (email != null) putExtra("email", email)
                        if (password != null) putExtra("password", password)
                    }
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }

                "stopLocationService" -> {
                    val intent = Intent(this, LocationForegroundService::class.java).apply {
                        action = LocationForegroundService.ACTION_STOP
                    }
                    stopService(intent)
                    result.success(true)
                }

                "isLocationServiceRunning" -> {
                    result.success(LocationForegroundService.isRunning)
                }

                "getLatestLocation" -> {
                    val prefs = getSharedPreferences(LocationForegroundService.PREFS_NAME, Context.MODE_PRIVATE)
                    val latBits = prefs.getLong(LocationForegroundService.KEY_LAST_LAT, -1L)
                    val lngBits = prefs.getLong(LocationForegroundService.KEY_LAST_LNG, -1L)
                    val accBits = prefs.getLong(LocationForegroundService.KEY_LAST_ACC, -1L)
                    val time = prefs.getString(LocationForegroundService.KEY_LAST_TIME, null)
                    val timeMillis = prefs.getLong(LocationForegroundService.KEY_LAST_TIME_MILLIS, -1L)
                    val gpsMillis = prefs.getLong(LocationForegroundService.KEY_LAST_GPS_MILLIS, timeMillis)
                    val serverMillis = prefs.getLong(LocationForegroundService.KEY_LAST_SERVER_MILLIS, -1L)

                    if (latBits != -1L && lngBits != -1L && accBits != -1L) {
                        val lat = java.lang.Double.longBitsToDouble(latBits)
                        val lng = java.lang.Double.longBitsToDouble(lngBits)
                        val acc = java.lang.Double.longBitsToDouble(accBits)

                        val map = mutableMapOf<String, Any>(
                            "latitude" to lat,
                            "longitude" to lng,
                            "accuracy" to acc,
                            "isServiceRunning" to LocationForegroundService.isRunning
                        )
                        if (time != null) {
                            map["timestamp"] = time
                        }
                        if (timeMillis != -1L) {
                            map["timestampMillis"] = timeMillis
                        }
                        if (gpsMillis != -1L) {
                            map["lastGpsMillis"] = gpsMillis
                        }
                        if (serverMillis != -1L) {
                            map["lastServerMillis"] = serverMillis
                        }
                        result.success(map)
                    } else {
                        result.success(null)
                    }
                }

                "isBatteryOptimizationIgnored" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val isIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        powerManager.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    result.success(isIgnored)
                }

                "requestIgnoreBatteryOptimization" -> {
                    try {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            if (powerManager.isIgnoringBatteryOptimizations(packageName)) {
                                result.success(true)
                                return@setMethodCallHandler
                            }
                            val intent = Intent().apply {
                                action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        try {
                            val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallbackIntent)
                            result.success(true)
                        } catch (e2: Exception) {
                            try {
                                val appDetailsIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$packageName")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(appDetailsIntent)
                                result.success(true)
                            } catch (e3: Exception) {
                                result.error("ERROR", e3.message, null)
                            }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
