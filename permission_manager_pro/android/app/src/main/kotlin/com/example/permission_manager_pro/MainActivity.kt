package com.example.permission_manager_pro

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Base64
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import rikka.shizuku.Shizuku
import rikka.shizuku.ShizukuBinderWrapper
import rikka.shizuku.SystemServiceHelper
import android.os.IBinder
import android.content.ComponentName

class MainActivity : FlutterActivity() {
    private val DIRECT_CHANNEL = "com.permguard.app/direct_permissions"
    private val SHIZUKU_CHANNEL = "com.permguard.app/shizuku"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Direct Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DIRECT_CHANNEL).setMethodCallHandler { call, result ->
            // ... (existing code handles this)
            handleDirectMethod(call, result)
        }

        // Shizuku Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHIZUKU_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isShizukuInstalled" -> result.success(isShizukuInstalled())
                "isShizukuRunning" -> result.success(Shizuku.pingBinder())
                "hasShizukuPermission" -> {
                    val granted = if (Shizuku.isPreV11()) false 
                                  else Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestShizukuPermission" -> {
                    Shizuku.addRequestPermissionResultListener(object : Shizuku.OnRequestPermissionResultListener {
                        override fun onRequestPermissionResult(requestCode: Int, grantResult: Int) {
                            Shizuku.removeRequestPermissionResultListener(this)
                            result.success(grantResult == PackageManager.PERMISSION_GRANTED)
                        }
                    })
                    Shizuku.requestPermission(1001)
                }
                "grantPermission" -> {
                    val packageName = call.argument<String>("packageName")
                    val permission = call.argument<String>("permission")
                    if (packageName != null && permission != null) {
                        val success = managePermissionViaShizuku(packageName, permission, true)
                        result.success(mapOf("success" to success))
                    } else {
                        result.error("INVALID_ARGUMENT", "Missing arguments", null)
                    }
                }
                "revokePermission" -> {
                    val packageName = call.argument<String>("packageName")
                    val permission = call.argument<String>("permission")
                    if (packageName != null && permission != null) {
                        val success = managePermissionViaShizuku(packageName, permission, false)
                        result.success(mapOf("success" to success))
                    } else {
                        result.error("INVALID_ARGUMENT", "Missing arguments", null)
                    }
                }
                "revokeAllLocationPermissions" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val p1 = managePermissionViaShizuku(packageName, "android.permission.ACCESS_FINE_LOCATION", false)
                        val p2 = managePermissionViaShizuku(packageName, "android.permission.ACCESS_COARSE_LOCATION", false)
                        managePermissionViaShizuku(packageName, "android.permission.ACCESS_BACKGROUND_LOCATION", false)
                        result.success(mapOf("allSuccess" to (p1 || p2)))
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isShizukuInstalled(): Boolean {
        return try {
            packageManager.getPackageInfo("dev.rikka.shizuku", 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun managePermissionViaShizuku(packageName: String, permission: String, grant: Boolean): Boolean {
        android.util.Log.d("ShizukuControl", "${if (grant) "Granting" else "Revoking"} $permission for $packageName")
        return try {
            val binder = ShizukuBinderWrapper(SystemServiceHelper.getSystemService("package"))
            val stubClass = Class.forName("android.content.pm.IPackageManager\$Stub")
            val asInterfaceMethod = stubClass.getMethod("asInterface", IBinder::class.java)
            val ipm = asInterfaceMethod.invoke(null, binder)
            
            val methodName = if (grant) "grantRuntimePermission" else "revokeRuntimePermission"
            
            // Handle different signatures based on SDK version
            val method = when {
                Build.VERSION.SDK_INT >= 34 -> { // Android 14
                    try {
                        // try with deviceId (SDK 34+)
                        ipm.javaClass.getMethod(methodName, String::class.java, String::class.java, Int::class.java, Int::class.java)
                    } catch (e: NoSuchMethodException) {
                        ipm.javaClass.getMethod(methodName, String::class.java, String::class.java, Int::class.java)
                    }
                }
                else -> {
                    ipm.javaClass.getMethod(methodName, String::class.java, String::class.java, Int::class.java)
                }
            }
            
            if (method.parameterCount == 4) {
                // deviceId is usually 0 (DEVICE_ID_DEFAULT)
                method.invoke(ipm, packageName, permission, 0, 0)
            } else {
                method.invoke(ipm, packageName, permission, 0)
            }
            
            android.util.Log.d("ShizukuControl", "Success")
            true
        } catch (e: Exception) {
            android.util.Log.e("ShizukuControl", "Failed: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    private fun handleDirectMethod(call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result) {
        when (call.method) {
            "detectCapabilities" -> {
                val caps = mutableMapOf<String, Any>()
                caps["appOpsAvailable"] = Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT
                caps["deviceAdminActive"] = false
                caps["androidVersion"] = Build.VERSION.SDK_INT
                caps["manufacturer"] = Build.MANUFACTURER
                result.success(caps)
            }
            "getInstalledApps" -> {
                val includeSystem = call.argument<Boolean>("includeSystemApps") ?: false
                result.success(getInstalledApps(includeSystem))
            }
            "getAppIcon" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    result.success(getAppIcon(packageName))
                } else {
                    result.error("INVALID_ARGUMENT", "Package name is null", null)
                }
            }
            "getPermissionState" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    result.success(getAppPermissionState(packageName))
                } else {
                    result.error("INVALID_ARGUMENT", "Package name is null", null)
                }
            }
            "togglePermission" -> {
                val packageName = call.argument<String>("packageName")
                val permission = call.argument<String>("permission")
                val allow = call.argument<Boolean>("allow") ?: false
                
                if (packageName != null && permission != null) {
                    val success = togglePermission(packageName, permission, allow)
                    result.success(mapOf("success" to success))
                } else {
                    result.error("INVALID_ARGUMENT", "Missing arguments", null)
                }
            }
            "openAppSettings" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    openAppSettings(packageName)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Package name is null", null)
                }
            }
            "hasUsageAccess" -> {
                result.success(hasUsageAccess())
            }
            "openUsageAccessSettings" -> {
                openUsageAccessSettings()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun getInstalledApps(includeSystem: Boolean): List<Map<String, Any?>> {
        val pm = packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val result = mutableListOf<Map<String, Any?>>()

        for (app in apps) {
            val isSystem = (app.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            if (!includeSystem && isSystem) continue

            val appInfo = mutableMapOf<String, Any?>()
            appInfo["packageName"] = app.packageName
            appInfo["appName"] = pm.getApplicationLabel(app).toString()
            appInfo["isSystemApp"] = isSystem
            // EXCLUDED iconBase64 for performance
            
            val state = getAppPermissionState(app.packageName)
            appInfo.putAll(state)
            
            result.add(appInfo)
        }
        return result
    }

    private fun getAppPermissionState(packageName: String): Map<String, Any?> {
        val pm = packageManager
        val state = mutableMapOf<String, Any?>()
        
        try {
            val pkgInfo = pm.getPackageInfo(packageName, PackageManager.GET_PERMISSIONS)
            val requested = pkgInfo.requestedPermissions ?: arrayOf<String>()
            state["requestedPermissions"] = requested.toList()
            
            // Location
            state["hasFineLocation"] = pm.checkPermission(android.Manifest.permission.ACCESS_FINE_LOCATION, packageName) == PackageManager.PERMISSION_GRANTED
            state["hasCoarseLocation"] = pm.checkPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION, packageName) == PackageManager.PERMISSION_GRANTED
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                state["hasBackgroundLocation"] = pm.checkPermission(android.Manifest.permission.ACCESS_BACKGROUND_LOCATION, packageName) == PackageManager.PERMISSION_GRANTED
            } else {
                state["hasBackgroundLocation"] = state["hasFineLocation"]
            }
            state["hasAnyLocation"] = (state["hasFineLocation"] as Boolean) || (state["hasCoarseLocation"] as Boolean)

            // Other Common Permissions
            state["hasCamera"] = pm.checkPermission(android.Manifest.permission.CAMERA, packageName) == PackageManager.PERMISSION_GRANTED
            state["hasMicrophone"] = pm.checkPermission(android.Manifest.permission.RECORD_AUDIO, packageName) == PackageManager.PERMISSION_GRANTED
            state["hasContacts"] = pm.checkPermission(android.Manifest.permission.READ_CONTACTS, packageName) == PackageManager.PERMISSION_GRANTED
            state["hasPhone"] = pm.checkPermission(android.Manifest.permission.READ_PHONE_STATE, packageName) == PackageManager.PERMISSION_GRANTED
            state["hasSms"] = pm.checkPermission(android.Manifest.permission.READ_SMS, packageName) == PackageManager.PERMISSION_GRANTED
            state["hasStorage"] = pm.checkPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE, packageName) == PackageManager.PERMISSION_GRANTED

            // AppOps check for blocked state (aggressive method)
            state["appOpsMode"] = getAppOpsMode(packageName)
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        return state
    }

    private fun getAppOpsMode(packageName: String): Int {
        return try {
            val pm = packageManager
            val ai = pm.getApplicationInfo(packageName, 0)
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            // Check for Location Op as representative
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_FINE_LOCATION, ai.uid, ai.packageName)
            } else {
                appOps.checkOpNoThrow(AppOpsManager.OPSTR_FINE_LOCATION, ai.uid, ai.packageName)
            }
        } catch (e: Exception) {
            3 // Default
        }
    }

    private fun togglePermission(packageName: String, permission: String, allow: Boolean): Boolean {
        return try {
            val pm = packageManager
            val ai = pm.getApplicationInfo(packageName, 0)
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (allow) AppOpsManager.MODE_ALLOWED else AppOpsManager.MODE_IGNORED
            
            // Map common permissions to AppOps
            val op = when (permission) {
                "LOCATION" -> AppOpsManager.OPSTR_FINE_LOCATION
                "CAMERA" -> AppOpsManager.OPSTR_CAMERA
                "MICROPHONE" -> AppOpsManager.OPSTR_RECORD_AUDIO
                "CONTACTS" -> AppOpsManager.OPSTR_READ_CONTACTS
                "PHONE" -> AppOpsManager.OPSTR_READ_PHONE_STATE
                "SMS" -> AppOpsManager.OPSTR_READ_SMS
                "STORAGE" -> AppOpsManager.OPSTR_READ_EXTERNAL_STORAGE
                else -> null
            }

            if (op != null) {
                // We use setMode which requires system signature or being an admin, 
                // but on many devices/Chinese ROMs it works with just standard hidden APIs if available.
                // For standard Android, this will fail unless we are Shizuku/Root.
                // However, we are implementing it here for cases where it DOES work.
                val setModeMethod = AppOpsManager::class.java.getMethod("setMode", Int::class.java, Int::class.java, String::class.java, Int::class.java)
                setModeMethod.invoke(appOps, getOpInt(op), ai.uid, packageName, mode)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun getOpInt(opStr: String): Int {
        // Fallback for getting integer op code from string
        return try {
            val method = AppOpsManager::class.java.getMethod("strOpToOp", String::class.java)
            method.invoke(null, opStr) as Int
        } catch (e: Exception) {
            -1
        }
    }

    private fun getAppIcon(packageName: String): ByteArray? {
        return try {
            val pm = packageManager
            val app = pm.getApplicationInfo(packageName, 0)
            val icon = app.loadIcon(pm)
            val bitmap = drawableToBitmap(icon)
            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            outputStream.toByteArray()
        } catch (e: Exception) {
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable) {
            return drawable.bitmap
        }
        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 100
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 100
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    private fun openAppSettings(packageName: String) {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.data = Uri.parse("package:$packageName")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun hasUsageAccess(): Boolean {
        return try {
            val pm = packageManager
            val ai = pm.getApplicationInfo(packageName, 0)
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, ai.uid, ai.packageName)
            } else {
                appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, ai.uid, ai.packageName)
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    private fun openUsageAccessSettings() {
        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
