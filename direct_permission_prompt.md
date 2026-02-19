You are an expert Flutter/Android developer. Build a complete, production-ready location permission management module for PermGuard that DIRECTLY modifies and manages other apps' location permissions. The user understands this requires special privileges. Implement ALL THREE methods below, layered in priority order. Write every file completely — no placeholders, no TODOs, no truncation.

---

# THE THREE EXECUTION PATHS (implement all three, auto-detect which to use)

## PATH 1 — Device Admin / Device Owner (Silent, no UI needed)
## PATH 2 — Shizuku ADB Bridge (Silent after one-time user setup)  
## PATH 3 — AppOps Manager (Works on many ROMs without root)

The app tries Path 3 → Path 2 → Path 1 in that order.
If none work, fall back to deep-link with instructions (Path 0).

---

# COMPLETE FILE STRUCTURE

```
android/app/src/main/
├── AndroidManifest.xml
└── kotlin/com/permguard/app/
    ├── MainActivity.kt
    ├── channel/
    │   ├── DirectPermissionChannel.kt
    │   ├── AppOpsChannel.kt
    │   └── ShizukuChannel.kt
    ├── admin/
    │   ├── PermGuardDeviceAdmin.kt
    │   └── DeviceAdminReceiver.xml (res/xml/)
    └── manager/
        ├── AppOpsPermissionManager.kt
        ├── DirectPermissionManager.kt
        └── AppScannerManager.kt

lib/
└── features/permission_manager/
    ├── data/
    │   ├── channel/
    │   │   └── permission_channel.dart
    │   └── repository/
    │       └── permission_repository_impl.dart
    ├── domain/
    │   ├── entity/
    │   │   └── app_info.dart
    │   ├── repository/
    │   │   └── permission_repository.dart
    │   └── usecase/
    │       ├── get_apps_usecase.dart
    │       ├── toggle_location_usecase.dart
    │       ├── batch_toggle_usecase.dart
    │       └── detect_permission_method_usecase.dart
    └── presentation/
        ├── bloc/
        │   ├── permission_bloc.dart
        │   ├── permission_event.dart
        │   └── permission_state.dart
        └── screen/
            ├── permission_list_screen.dart
            └── widget/
                ├── app_permission_tile.dart
                ├── permission_method_banner.dart
                ├── direct_toggle.dart
                └── shizuku_setup_sheet.dart
```

---

# ANDROID — KOTLIN FILES

## AndroidManifest.xml additions

```xml
<!-- ALL required permissions -->
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES"
    tools:ignore="QueryAllPackagesPermission"/>
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
    tools:ignore="ProtectedPermissions"/>
<uses-permission android:name="android.permission.GET_APP_OPS_STATS"
    tools:ignore="ProtectedPermissions"/>
<uses-permission android:name="android.permission.MANAGE_APP_OPS_MODES"
    tools:ignore="ProtectedPermissions"/>

<!-- Device Admin receiver registration -->
<receiver
    android:name=".admin.PermGuardDeviceAdmin"
    android:description="@string/device_admin_description"
    android:label="@string/device_admin_label"
    android:permission="android.permission.BIND_DEVICE_ADMIN"
    android:exported="true">
    <meta-data
        android:name="android.app.device_admin"
        android:resource="@xml/device_admin_receiver"/>
    <intent-filter>
        <action android:name="android.app.action.DEVICE_ADMIN_ENABLED"/>
    </intent-filter>
</receiver>

<!-- Shizuku provider -->
<provider
    android:name="rikka.shizuku.ShizukuProvider"
    android:authorities="${applicationId}.shizuku"
    android:multiprocess="false"
    android:enabled="true"
    android:exported="true"
    android:permission="android.permission.INTERACT_ACROSS_USERS_FULL"/>
```

## res/xml/device_admin_receiver.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<device-admin>
    <uses-policies>
        <limit-password/>
        <watch-login/>
        <reset-password/>
        <force-lock/>
        <wipe-data/>
        <expire-password/>
        <encrypted-storage/>
        <disable-camera/>
        <disable-keyguard-features/>
    </uses-policies>
</device-admin>
```

## android/.../admin/PermGuardDeviceAdmin.kt

```kotlin
package com.permguard.app.admin

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

class PermGuardDeviceAdmin : DeviceAdminReceiver() {

    override fun onEnabled(context: Context, intent: Intent) {
        Toast.makeText(context, "PermGuard Device Admin enabled", Toast.LENGTH_SHORT).show()
    }

    override fun onDisabled(context: Context, intent: Intent) {
        Toast.makeText(context, "PermGuard Device Admin disabled", Toast.LENGTH_SHORT).show()
    }

    override fun onPasswordChanged(context: Context, intent: Intent) {}
    override fun onPasswordFailed(context: Context, intent: Intent) {}
    override fun onPasswordSucceeded(context: Context, intent: Intent) {}
}
```

## android/.../manager/AppOpsPermissionManager.kt

```kotlin
package com.permguard.app.manager

import android.app.AppOpsManager
import android.content.Context
import android.content.pm.PackageManager
import java.lang.reflect.Method

/**
 * PATH 3: AppOps Manager
 *
 * AppOpsManager.setMode() can modify permission behavior on many Android ROMs
 * (especially MIUI, ColorOS, OneUI) without root.
 *
 * Standard Android blocks setMode() for apps that aren't system apps.
 * However, on many manufacturer ROMs this check is relaxed.
 *
 * We use reflection to access the hidden setMode() overload that accepts UID.
 *
 * Op codes for location:
 *   OP_FINE_LOCATION   = 1
 *   OP_COARSE_LOCATION = 0
 *   OP_MONITOR_HIGH_POWER_LOCATION = 42
 *   OP_MONITOR_LOCATION = 41
 */
class AppOpsPermissionManager(private val context: Context) {

    private val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
    private val packageManager = context.packageManager

    companion object {
        const val OP_COARSE_LOCATION = 0
        const val OP_FINE_LOCATION = 1
        const val OP_MONITOR_LOCATION = 41
        const val OP_MONITOR_HIGH_POWER_LOCATION = 42
        const val OP_MOCK_LOCATION = 58

        const val MODE_ALLOWED = AppOpsManager.MODE_ALLOWED       // 0
        const val MODE_IGNORED = AppOpsManager.MODE_IGNORED       // 1
        const val MODE_ERRORED = AppOpsManager.MODE_ERRORED       // 2 (throws SecurityException to app)
        const val MODE_DEFAULT = AppOpsManager.MODE_DEFAULT       // 3
        const val MODE_FOREGROUND = 4                              // Allow only in foreground
    }

    /**
     * Attempt to directly set location permission mode for a package.
     * Returns true if successfully changed, false if blocked by ROM security.
     *
     * Uses reflection to access AppOpsManager.setMode(int, int, String, int)
     * which is the hidden API that accepts uid + packageName.
     */
    fun setLocationPermission(packageName: String, allow: Boolean): Boolean {
        return try {
            val uid = packageManager.getPackageUid(packageName, 0)
            val targetMode = if (allow) MODE_ALLOWED else MODE_IGNORED

            var success = false

            // Try reflection-based setMode (hidden API)
            success = trySetModeViaReflection(OP_FINE_LOCATION, uid, packageName, targetMode)
            trySetModeViaReflection(OP_COARSE_LOCATION, uid, packageName, targetMode)

            // Also try the AppOpsManager string-based ops (Android 10+)
            if (!success) {
                success = trySetModeByOp(
                    AppOpsManager.OPSTR_FINE_LOCATION, uid, packageName, targetMode
                )
                trySetModeByOp(
                    AppOpsManager.OPSTR_COARSE_LOCATION, uid, packageName, targetMode
                )
            }

            success
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Get the current AppOps mode for location permission of a package.
     */
    fun getLocationMode(packageName: String): Int {
        return try {
            val uid = packageManager.getPackageUid(packageName, 0)
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_FINE_LOCATION,
                uid,
                packageName
            )
        } catch (e: Exception) {
            MODE_DEFAULT
        }
    }

    /**
     * Test if AppOps setMode is permitted on this ROM.
     * Call this once on startup to determine capability.
     */
    fun canUseAppOps(): Boolean {
        return try {
            // Attempt to read our own app ops — if this works, we likely have access
            val setModeMethod = getSetModeMethod() ?: return false
            // Don't actually call it — just check it's accessible
            setModeMethod != null
        } catch (e: SecurityException) {
            false
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Revoke background location specifically (most privacy-sensitive)
     */
    fun revokeBackgroundLocation(packageName: String): Boolean {
        return try {
            val uid = packageManager.getPackageUid(packageName, 0)
            // Set to MODE_FOREGROUND — allows foreground but not background
            trySetModeViaReflection(OP_FINE_LOCATION, uid, packageName, MODE_FOREGROUND)
            trySetModeViaReflection(OP_COARSE_LOCATION, uid, packageName, MODE_FOREGROUND)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun trySetModeViaReflection(op: Int, uid: Int, packageName: String, mode: Int): Boolean {
        return try {
            val method = getSetModeMethod() ?: return false
            method.invoke(appOps, op, uid, packageName, mode)
            true
        } catch (e: SecurityException) {
            false
        } catch (e: Exception) {
            false
        }
    }

    private fun trySetModeByOp(opStr: String, uid: Int, packageName: String, mode: Int): Boolean {
        return try {
            // AppOpsManager.setMode(String, int, String, int) — Android 10+
            val method = AppOpsManager::class.java.getMethod(
                "setMode",
                String::class.java,
                Int::class.javaPrimitiveType,
                String::class.java,
                Int::class.javaPrimitiveType
            )
            method.invoke(appOps, opStr, uid, packageName, mode)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun getSetModeMethod(): Method? {
        return try {
            // Hidden API: AppOpsManager.setMode(int op, int uid, String packageName, int mode)
            AppOpsManager::class.java.getMethod(
                "setMode",
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
                String::class.java,
                Int::class.javaPrimitiveType
            )
        } catch (e: NoSuchMethodException) {
            null
        }
    }
}
```

## android/.../manager/DirectPermissionManager.kt

```kotlin
package com.permguard.app.manager

import android.Manifest
import android.app.AppOpsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Base64
import java.io.ByteArrayOutputStream

/**
 * Unified permission manager that reads all app data
 * and routes modification through the correct path.
 */
class DirectPermissionManager(private val context: Context) {

    private val packageManager = context.packageManager
    private val appOpsManager = AppOpsPermissionManager(context)
    private val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager

    /**
     * Returns all installed apps with location permission states.
     */
    fun getInstalledApps(includeSystemApps: Boolean): List<Map<String, Any?>> {
        return packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
            .filter { appInfo ->
                val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                val isUpdatedSystem = (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
                if (!includeSystemApps) (!isSystem || isUpdatedSystem) else true
            }
            .filter { it.packageName != context.packageName }
            .map { appInfo ->
                val hasFine = checkPermission(appInfo.packageName, Manifest.permission.ACCESS_FINE_LOCATION)
                val hasCoarse = checkPermission(appInfo.packageName, Manifest.permission.ACCESS_COARSE_LOCATION)
                val hasBg = checkPermission(appInfo.packageName, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
                val opsMode = appOpsManager.getLocationMode(appInfo.packageName)

                val pkgInfo = runCatching {
                    packageManager.getPackageInfo(appInfo.packageName, 0)
                }.getOrNull()

                mapOf(
                    "packageName" to appInfo.packageName,
                    "appName" to packageManager.getApplicationLabel(appInfo).toString(),
                    "iconBase64" to getIconBase64(appInfo),
                    "hasFineLocation" to hasFine,
                    "hasCoarseLocation" to hasCoarse,
                    "hasBackgroundLocation" to hasBg,
                    "hasAnyLocation" to (hasFine || hasCoarse),
                    "appOpsMode" to opsMode,  // 0=allowed, 1=ignored, 4=foreground
                    "isSystemApp" to ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                    "installTime" to (pkgInfo?.firstInstallTime ?: 0L),
                    "versionName" to (pkgInfo?.versionName ?: ""),
                    "targetSdk" to appInfo.targetSdkVersion
                )
            }
            .sortedWith(
                compareByDescending<Map<String, Any?>> { (it["hasAnyLocation"] as? Boolean) == true }
                    .thenBy { it["appName"] as? String ?: "" }
            )
    }

    /**
     * Main toggle method — tries AppOps first, reports capability back.
     */
    fun toggleLocationPermission(
        packageName: String,
        allow: Boolean
    ): Map<String, Any> {
        // Attempt AppOps path
        val appOpsSuccess = appOpsManager.setLocationPermission(packageName, allow)

        if (appOpsSuccess) {
            // Verify the change actually took effect
            val newMode = appOpsManager.getLocationMode(packageName)
            val effectivelyChanged = if (allow) {
                newMode == AppOpsManager.MODE_ALLOWED || newMode == AppOpsManager.MODE_DEFAULT
            } else {
                newMode == AppOpsManager.MODE_IGNORED || newMode == AppOpsManager.MODE_ERRORED
            }

            return mapOf(
                "success" to effectivelyChanged,
                "method" to "appops",
                "newMode" to newMode,
                "message" to if (effectivelyChanged) "Permission changed via AppOps" else "AppOps call succeeded but state unchanged"
            )
        }

        // AppOps failed — report that Shizuku or manual is needed
        return mapOf(
            "success" to false,
            "method" to "none",
            "newMode" to -1,
            "requiresShizuku" to true,
            "message" to "AppOps blocked on this ROM — Shizuku required for direct control"
        )
    }

    /**
     * Revoke only background location, keep foreground.
     * Less invasive — works on more devices.
     */
    fun revokeBackgroundLocationOnly(packageName: String): Map<String, Any> {
        val success = appOpsManager.revokeBackgroundLocation(packageName)
        return mapOf(
            "success" to success,
            "method" to if (success) "appops_foreground" else "none",
            "message" to if (success) "Background location revoked" else "Revocation failed"
        )
    }

    /**
     * Detect what direct-control capabilities are available on this device.
     */
    fun detectCapabilities(): Map<String, Any> {
        return mapOf(
            "appOpsAvailable" to appOpsManager.canUseAppOps(),
            "deviceAdminActive" to isDeviceAdminActive(),
            "androidVersion" to android.os.Build.VERSION.SDK_INT,
            "manufacturer" to android.os.Build.MANUFACTURER.lowercase(),
            "model" to android.os.Build.MODEL
        )
    }

    fun getPermissionState(packageName: String): Map<String, Any?> {
        val hasFine = checkPermission(packageName, Manifest.permission.ACCESS_FINE_LOCATION)
        val hasCoarse = checkPermission(packageName, Manifest.permission.ACCESS_COARSE_LOCATION)
        val hasBg = checkPermission(packageName, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        val opsMode = appOpsManager.getLocationMode(packageName)

        return mapOf(
            "packageName" to packageName,
            "hasFineLocation" to hasFine,
            "hasCoarseLocation" to hasCoarse,
            "hasBackgroundLocation" to hasBg,
            "hasAnyLocation" to (hasFine || hasCoarse),
            "appOpsMode" to opsMode
        )
    }

    private fun checkPermission(packageName: String, permission: String): Boolean {
        return try {
            packageManager.checkPermission(permission, packageName) ==
                PackageManager.PERMISSION_GRANTED
        } catch (e: Exception) { false }
    }

    private fun isDeviceAdminActive(): Boolean {
        return try {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE)
                as android.app.admin.DevicePolicyManager
            val adminComponent = android.content.ComponentName(
                context, com.permguard.app.admin.PermGuardDeviceAdmin::class.java
            )
            dpm.isAdminActive(adminComponent)
        } catch (e: Exception) { false }
    }

    private fun getIconBase64(appInfo: ApplicationInfo): String? {
        return runCatching {
            val drawable = packageManager.getApplicationIcon(appInfo)
            val bmp = drawableToBitmap(drawable)
            val stream = ByteArrayOutputStream()
            bmp.compress(Bitmap.CompressFormat.PNG, 80, stream)
            Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
        }.getOrNull()
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) return drawable.bitmap
        val w = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 48
        val h = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 48
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        drawable.setBounds(0, 0, w, h)
        drawable.draw(canvas)
        return bmp
    }
}
```

## android/.../channel/DirectPermissionChannel.kt

```kotlin
package com.permguard.app.channel

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.permguard.app.manager.DirectPermissionManager
import com.permguard.app.manager.UsageStatsHelper

class DirectPermissionChannel(
    private val context: Context,
    flutterEngine: FlutterEngine
) {
    companion object {
        const val CHANNEL = "com.permguard.app/direct_permissions"
    }

    private val manager = DirectPermissionManager(context)
    private val usageHelper = UsageStatsHelper(context)

    init {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // Returns List<Map> — all apps with permission states
                    "getInstalledApps" -> {
                        val includeSystem = call.argument<Boolean>("includeSystemApps") ?: false
                        try {
                            result.success(manager.getInstalledApps(includeSystem))
                        } catch (e: Exception) {
                            result.error("SCAN_ERROR", e.message, null)
                        }
                    }

                    // Returns Map with success/method/message
                    "toggleLocationPermission" -> {
                        val packageName = call.argument<String>("packageName")
                            ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        val allow = call.argument<Boolean>("allow") ?: false
                        try {
                            result.success(manager.toggleLocationPermission(packageName, allow))
                        } catch (e: Exception) {
                            result.error("TOGGLE_ERROR", e.message, null)
                        }
                    }

                    // Revoke only background location — less aggressive
                    "revokeBackgroundLocation" -> {
                        val packageName = call.argument<String>("packageName")
                            ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        try {
                            result.success(manager.revokeBackgroundLocationOnly(packageName))
                        } catch (e: Exception) {
                            result.error("REVOKE_ERROR", e.message, null)
                        }
                    }

                    // Batch toggle — accepts List<String> packageNames
                    "batchToggleLocationPermission" -> {
                        val packageNames = call.argument<List<String>>("packageNames")
                            ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageNames required", null)
                        val allow = call.argument<Boolean>("allow") ?: false
                        val results = packageNames.associate { pkg ->
                            pkg to manager.toggleLocationPermission(pkg, allow)
                        }
                        result.success(results)
                    }

                    // Refresh single app permission state
                    "getPermissionState" -> {
                        val packageName = call.argument<String>("packageName")
                            ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        result.success(manager.getPermissionState(packageName))
                    }

                    // Detect device capabilities
                    "detectCapabilities" -> {
                        result.success(manager.detectCapabilities())
                    }

                    // Usage stats
                    "getLocationAccessHistory" -> {
                        try {
                            result.success(usageHelper.getLocationAccessHistory())
                        } catch (e: Exception) {
                            result.success(emptyMap<String, Long>())
                        }
                    }

                    "hasUsageAccess" -> {
                        result.success(usageHelper.hasUsageAccessPermission())
                    }

                    "openUsageAccessSettings" -> {
                        val intent = android.content.Intent(
                            android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS
                        ).apply { addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK) }
                        context.startActivity(intent)
                        result.success(true)
                    }

                    // Fallback: open system settings for specific app
                    "openAppSettings" -> {
                        val packageName = call.argument<String>("packageName")
                            ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        val intent = android.content.Intent(
                            android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                        ).apply {
                            data = android.net.Uri.fromParts("package", packageName, null)
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
```

## android/.../channel/ShizukuChannel.kt

```kotlin
package com.permguard.app.channel

import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import rikka.shizuku.ShizukuRemoteProcess

/**
 * PATH 2: Shizuku channel.
 *
 * Shizuku lets PermGuard run privileged commands via an ADB-level
 * shell that the user sets up once. No root required.
 *
 * Requires in build.gradle.kts:
 *   implementation("dev.rikka.shizuku:api:13.1.5")
 *   implementation("dev.rikka.shizuku:provider:13.1.5")
 *
 * How it works:
 * 1. User installs Shizuku from Play Store
 * 2. User enables Shizuku (via wireless debugging on Android 11+, takes 30 seconds)
 * 3. PermGuard requests Shizuku permission (one dialog)
 * 4. PermGuard can now run `pm revoke <package> <permission>` via shell
 */
class ShizukuChannel(
    private val context: Context,
    flutterEngine: FlutterEngine
) {
    companion object {
        const val CHANNEL = "com.permguard.app/shizuku"
        private const val REQUEST_CODE = 100
    }

    init {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "isShizukuInstalled" -> {
                        val installed = runCatching {
                            context.packageManager.getPackageInfo("moe.shizuku.privileged.api", 0)
                            true
                        }.getOrDefault(false)
                        result.success(installed)
                    }

                    "isShizukuRunning" -> {
                        val running = runCatching { Shizuku.pingBinder() }.getOrDefault(false)
                        result.success(running)
                    }

                    "hasShizukuPermission" -> {
                        val hasPermission = runCatching {
                            Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
                        }.getOrDefault(false)
                        result.success(hasPermission)
                    }

                    "requestShizukuPermission" -> {
                        try {
                            if (Shizuku.shouldShowRequestPermissionRationale()) {
                                result.error("RATIONALE", "Show rationale to user", null)
                            } else {
                                Shizuku.requestPermission(REQUEST_CODE)
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            result.error("REQUEST_ERROR", e.message, null)
                        }
                    }

                    // THE KEY METHOD: revoke permission via shell command
                    // Uses `pm revoke <packageName> <permission>`
                    "revokePermission" -> {
                        val packageName = call.argument<String>("packageName")
                            ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        val permission = call.argument<String>("permission")
                            ?: return@setMethodCallHandler result.error("MISSING_ARG", "permission required", null)

                        try {
                            if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
                                result.error("NO_PERMISSION", "Shizuku permission not granted", null)
                                return@setMethodCallHandler
                            }

                            // Run pm revoke command via Shizuku shell
                            val process = Shizuku.newProcess(
                                arrayOf("pm", "revoke", packageName, permission),
                                null, null
                            )
                            val exitCode = process.waitFor()
                            val output = process.inputStream.bufferedReader().readText()
                            val error = process.errorStream.bufferedReader().readText()

                            result.success(mapOf(
                                "success" to (exitCode == 0),
                                "exitCode" to exitCode,
                                "output" to output,
                                "error" to error
                            ))
                        } catch (e: Exception) {
                            result.error("SHIZUKU_ERROR", e.message, null)
                        }
                    }

                    // Grant permission via shell (for restore)
                    "grantPermission" -> {
                        val packageName = call.argument<String>("packageName")
                            ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)
                        val permission = call.argument<String>("permission")
                            ?: return@setMethodCallHandler result.error("MISSING_ARG", "permission required", null)

                        try {
                            if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
                                result.error("NO_PERMISSION", "Shizuku permission not granted", null)
                                return@setMethodCallHandler
                            }

                            val process = Shizuku.newProcess(
                                arrayOf("pm", "grant", packageName, permission),
                                null, null
                            )
                            val exitCode = process.waitFor()

                            result.success(mapOf(
                                "success" to (exitCode == 0),
                                "exitCode" to exitCode
                            ))
                        } catch (e: Exception) {
                            result.error("SHIZUKU_ERROR", e.message, null)
                        }
                    }

                    // Batch revoke all location permissions for a package
                    "revokeAllLocationPermissions" -> {
                        val packageName = call.argument<String>("packageName")
                            ?: return@setMethodCallHandler result.error("MISSING_ARG", "packageName required", null)

                        val permissions = listOf(
                            "android.permission.ACCESS_FINE_LOCATION",
                            "android.permission.ACCESS_COARSE_LOCATION",
                            "android.permission.ACCESS_BACKGROUND_LOCATION"
                        )

                        if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
                            result.error("NO_PERMISSION", "Shizuku permission not granted", null)
                            return@setMethodCallHandler
                        }

                        var allSuccess = true
                        val results = mutableMapOf<String, Boolean>()

                        permissions.forEach { permission ->
                            try {
                                val process = Shizuku.newProcess(
                                    arrayOf("pm", "revoke", packageName, permission),
                                    null, null
                                )
                                val exitCode = process.waitFor()
                                results[permission] = exitCode == 0
                                if (exitCode != 0) allSuccess = false
                            } catch (e: Exception) {
                                results[permission] = false
                                allSuccess = false
                            }
                        }

                        result.success(mapOf(
                            "allSuccess" to allSuccess,
                            "results" to results
                        ))
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
```

## android/.../MainActivity.kt

```kotlin
package com.permguard.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.permguard.app.channel.DirectPermissionChannel
import com.permguard.app.channel.ShizukuChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DirectPermissionChannel(applicationContext, flutterEngine)
        ShizukuChannel(applicationContext, flutterEngine)
    }
}
```

---

# FLUTTER / DART FILES

## lib/features/permission_manager/data/channel/permission_channel.dart

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../../domain/entity/app_info.dart';

class PermissionChannel {
  static const _direct = MethodChannel('com.permguard.app/direct_permissions');
  static const _shizuku = MethodChannel('com.permguard.app/shizuku');

  // ─── Capabilities Detection ──────────────────────────────────────────────

  Future<DeviceCapabilities> detectCapabilities() async {
    final raw = await _direct.invokeMethod<Map>('detectCapabilities');
    final map = Map<String, dynamic>.from(raw ?? {});

    final shizukuInstalled = await _safeCall<bool>(
      () => _shizuku.invokeMethod('isShizukuInstalled'), false);
    final shizukuRunning = shizukuInstalled
      ? await _safeCall<bool>(() => _shizuku.invokeMethod('isShizukuRunning'), false)
      : false;
    final shizukuPermission = shizukuRunning
      ? await _safeCall<bool>(() => _shizuku.invokeMethod('hasShizukuPermission'), false)
      : false;

    return DeviceCapabilities(
      appOpsAvailable: map['appOpsAvailable'] as bool? ?? false,
      deviceAdminActive: map['deviceAdminActive'] as bool? ?? false,
      shizukuInstalled: shizukuInstalled,
      shizukuRunning: shizukuRunning,
      shizukuPermissionGranted: shizukuPermission,
      androidVersion: map['androidVersion'] as int? ?? 0,
      manufacturer: map['manufacturer'] as String? ?? '',
    );
  }

  // ─── App Scanning ─────────────────────────────────────────────────────────

  Future<List<AppInfo>> getInstalledApps({bool includeSystem = false}) async {
    final raw = await _direct.invokeMethod<List>(
      'getInstalledApps', {'includeSystemApps': includeSystem});

    Map<String, int> history = {};
    try {
      final histRaw = await _direct.invokeMethod<Map>('getLocationAccessHistory');
      if (histRaw != null) {
        history = histRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
    } catch (_) {}

    return (raw ?? []).map((item) {
      final m = Map<String, dynamic>.from(item as Map);
      final pkg = m['packageName'] as String;

      Uint8List? icon;
      final b64 = m['iconBase64'] as String?;
      if (b64 != null && b64.isNotEmpty) {
        icon = base64Decode(b64);
      }

      return AppInfo(
        packageName: pkg,
        appName: m['appName'] as String? ?? pkg,
        iconBytes: icon,
        hasFineLocation: m['hasFineLocation'] as bool? ?? false,
        hasCoarseLocation: m['hasCoarseLocation'] as bool? ?? false,
        hasBackgroundLocation: m['hasBackgroundLocation'] as bool? ?? false,
        hasAnyLocation: m['hasAnyLocation'] as bool? ?? false,
        appOpsMode: m['appOpsMode'] as int? ?? 3,
        isSystemApp: m['isSystemApp'] as bool? ?? false,
        installTime: (m['installTime'] as num?)?.toInt() ?? 0,
        versionName: m['versionName'] as String? ?? '',
        targetSdk: (m['targetSdk'] as num?)?.toInt() ?? 0,
        lastLocationAccessMs: history[pkg],
      );
    }).toList();
  }

  Future<AppInfo> refreshApp(AppInfo app) async {
    final raw = await _direct.invokeMethod<Map>(
      'getPermissionState', {'packageName': app.packageName});
    final m = Map<String, dynamic>.from(raw ?? {});
    return app.copyWith(
      hasFineLocation: m['hasFineLocation'] as bool?,
      hasCoarseLocation: m['hasCoarseLocation'] as bool?,
      hasBackgroundLocation: m['hasBackgroundLocation'] as bool?,
      hasAnyLocation: m['hasAnyLocation'] as bool?,
      appOpsMode: m['appOpsMode'] as int?,
    );
  }

  // ─── Permission Toggling — Core Logic ────────────────────────────────────

  /// Toggle location permission using the best available method.
  /// Returns [ToggleResult] with method used and success state.
  Future<ToggleResult> toggleLocation({
    required String packageName,
    required bool allow,
    required DeviceCapabilities caps,
  }) async {
    // PATH 2: Shizuku — most reliable direct control
    if (caps.shizukuPermissionGranted) {
      final result = await _toggleViaShizuku(packageName: packageName, allow: allow);
      if (result.success) return result;
    }

    // PATH 3: AppOps — works on MIUI, ColorOS, many custom ROMs
    if (caps.appOpsAvailable) {
      final result = await _toggleViaAppOps(packageName: packageName, allow: allow);
      if (result.success) return result;
    }

    // PATH 0: Fallback — open system settings
    return ToggleResult(
      success: false,
      method: ToggleMethod.fallback,
      message: 'Direct control unavailable — opening system settings',
      requiresFallback: true,
    );
  }

  Future<ToggleResult> _toggleViaShizuku({
    required String packageName,
    required bool allow,
  }) async {
    try {
      if (allow) {
        // Grant back all location permissions
        final permissions = [
          'android.permission.ACCESS_FINE_LOCATION',
          'android.permission.ACCESS_COARSE_LOCATION',
        ];
        bool allOk = true;
        for (final perm in permissions) {
          final raw = await _shizuku.invokeMethod<Map>(
            'grantPermission', {'packageName': packageName, 'permission': perm});
          final result = Map<String, dynamic>.from(raw ?? {});
          if (result['success'] != true) allOk = false;
        }
        return ToggleResult(
          success: allOk,
          method: ToggleMethod.shizuku,
          message: allOk ? 'Location granted via Shizuku' : 'Some permissions failed',
        );
      } else {
        // Revoke all location permissions
        final raw = await _shizuku.invokeMethod<Map>(
          'revokeAllLocationPermissions', {'packageName': packageName});
        final result = Map<String, dynamic>.from(raw ?? {});
        return ToggleResult(
          success: result['allSuccess'] as bool? ?? false,
          method: ToggleMethod.shizuku,
          message: result['allSuccess'] == true
            ? 'All location permissions revoked via Shizuku'
            : 'Some revocations failed',
        );
      }
    } on PlatformException catch (e) {
      return ToggleResult(
        success: false,
        method: ToggleMethod.shizuku,
        message: e.message ?? 'Shizuku error',
      );
    }
  }

  Future<ToggleResult> _toggleViaAppOps({
    required String packageName,
    required bool allow,
  }) async {
    try {
      final raw = await _direct.invokeMethod<Map>(
        'toggleLocationPermission',
        {'packageName': packageName, 'allow': allow},
      );
      final result = Map<String, dynamic>.from(raw ?? {});
      return ToggleResult(
        success: result['success'] as bool? ?? false,
        method: ToggleMethod.appOps,
        message: result['message'] as String? ?? '',
        requiresShizuku: result['requiresShizuku'] as bool? ?? false,
      );
    } on PlatformException catch (e) {
      return ToggleResult(
        success: false,
        method: ToggleMethod.appOps,
        message: e.message ?? 'AppOps error',
      );
    }
  }

  /// Batch toggle for multiple apps
  Future<Map<String, ToggleResult>> batchToggle({
    required List<String> packageNames,
    required bool allow,
    required DeviceCapabilities caps,
  }) async {
    final results = <String, ToggleResult>{};
    for (final pkg in packageNames) {
      results[pkg] = await toggleLocation(
        packageName: pkg, allow: allow, caps: caps);
    }
    return results;
  }

  // ─── Shizuku Setup ────────────────────────────────────────────────────────

  Future<bool> requestShizukuPermission() async {
    return _safeCall<bool>(
      () => _shizuku.invokeMethod('requestShizukuPermission'), false);
  }

  Future<void> openAppSettings(String packageName) async {
    await _direct.invokeMethod('openAppSettings', {'packageName': packageName});
  }

  Future<void> openUsageAccessSettings() async {
    await _direct.invokeMethod('openUsageAccessSettings');
  }

  Future<bool> hasUsageAccess() async {
    return _safeCall<bool>(() => _direct.invokeMethod('hasUsageAccess'), false);
  }

  Future<T> _safeCall<T>(Future<T?> Function() fn, T fallback) async {
    try { return await fn() ?? fallback; } catch (_) { return fallback; }
  }
}

// ─── Result & Capability Models ──────────────────────────────────────────────

enum ToggleMethod { shizuku, appOps, deviceAdmin, fallback }

class ToggleResult {
  final bool success;
  final ToggleMethod method;
  final String message;
  final bool requiresFallback;
  final bool requiresShizuku;

  const ToggleResult({
    required this.success,
    required this.method,
    required this.message,
    this.requiresFallback = false,
    this.requiresShizuku = false,
  });
}

class DeviceCapabilities {
  final bool appOpsAvailable;
  final bool deviceAdminActive;
  final bool shizukuInstalled;
  final bool shizukuRunning;
  final bool shizukuPermissionGranted;
  final int androidVersion;
  final String manufacturer;

  const DeviceCapabilities({
    required this.appOpsAvailable,
    required this.deviceAdminActive,
    required this.shizukuInstalled,
    required this.shizukuRunning,
    required this.shizukuPermissionGranted,
    required this.androidVersion,
    required this.manufacturer,
  });

  /// Best available method on this device
  ToggleMethod get bestMethod {
    if (shizukuPermissionGranted) return ToggleMethod.shizuku;
    if (appOpsAvailable) return ToggleMethod.appOps;
    if (deviceAdminActive) return ToggleMethod.deviceAdmin;
    return ToggleMethod.fallback;
  }

  bool get canDirectlyControl =>
    shizukuPermissionGranted || appOpsAvailable || deviceAdminActive;

  String get methodLabel {
    switch (bestMethod) {
      case ToggleMethod.shizuku: return 'Shizuku (Full Control)';
      case ToggleMethod.appOps: return 'AppOps (Direct)';
      case ToggleMethod.deviceAdmin: return 'Device Admin';
      case ToggleMethod.fallback: return 'Manual (Settings)';
    }
  }
}
```

## lib/features/permission_manager/domain/entity/app_info.dart

```dart
import 'dart:typed_data';

class AppInfo {
  final String packageName;
  final String appName;
  final Uint8List? iconBytes;
  final bool hasFineLocation;
  final bool hasCoarseLocation;
  final bool hasBackgroundLocation;
  final bool hasAnyLocation;
  final int appOpsMode; // 0=allowed, 1=ignored, 3=default, 4=foreground
  final bool isSystemApp;
  final int installTime;
  final String versionName;
  final int targetSdk;
  final int? lastLocationAccessMs;
  final bool isSelected; // For multi-select UI
  final bool isLoading;  // Toggle in progress

  const AppInfo({
    required this.packageName,
    required this.appName,
    this.iconBytes,
    required this.hasFineLocation,
    required this.hasCoarseLocation,
    required this.hasBackgroundLocation,
    required this.hasAnyLocation,
    this.appOpsMode = 3,
    required this.isSystemApp,
    required this.installTime,
    required this.versionName,
    required this.targetSdk,
    this.lastLocationAccessMs,
    this.isSelected = false,
    this.isLoading = false,
  });

  String get lastAccessLabel {
    if (lastLocationAccessMs == null) return 'Never';
    final diff = DateTime.now().millisecondsSinceEpoch - lastLocationAccessMs!;
    if (diff < 300000) return 'Active now';
    if (diff < 3600000) return '${diff ~/ 60000}m ago';
    if (diff < 86400000) return '${diff ~/ 3600000}h ago';
    return '${diff ~/ 86400000}d ago';
  }

  bool get isActiveNow =>
    lastLocationAccessMs != null &&
    DateTime.now().millisecondsSinceEpoch - lastLocationAccessMs! < 300000;

  bool get isEffectivelyBlocked => appOpsMode == 1 || appOpsMode == 2;

  AppInfo copyWith({
    bool? hasFineLocation,
    bool? hasCoarseLocation,
    bool? hasBackgroundLocation,
    bool? hasAnyLocation,
    int? appOpsMode,
    bool? isSelected,
    bool? isLoading,
    int? lastLocationAccessMs,
  }) => AppInfo(
    packageName: packageName,
    appName: appName,
    iconBytes: iconBytes,
    hasFineLocation: hasFineLocation ?? this.hasFineLocation,
    hasCoarseLocation: hasCoarseLocation ?? this.hasCoarseLocation,
    hasBackgroundLocation: hasBackgroundLocation ?? this.hasBackgroundLocation,
    hasAnyLocation: hasAnyLocation ?? this.hasAnyLocation,
    appOpsMode: appOpsMode ?? this.appOpsMode,
    isSystemApp: isSystemApp,
    installTime: installTime,
    versionName: versionName,
    targetSdk: targetSdk,
    lastLocationAccessMs: lastLocationAccessMs ?? this.lastLocationAccessMs,
    isSelected: isSelected ?? this.isSelected,
    isLoading: isLoading ?? this.isLoading,
  );
}
```

## lib/features/permission_manager/presentation/bloc/permission_bloc.dart

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/channel/permission_channel.dart';
import '../../domain/entity/app_info.dart';
import 'permission_event.dart';
import 'permission_state.dart';

class PermissionBloc extends Bloc<PermissionEvent, PermissionState> {
  final PermissionChannel _channel;
  DeviceCapabilities? _caps;

  PermissionBloc({required PermissionChannel channel})
    : _channel = channel,
      super(const PermissionState()) {
    on<LoadApps>(_onLoadApps);
    on<ToggleLocation>(_onToggleLocation);
    on<BatchToggle>(_onBatchToggle);
    on<RefreshApp>(_onRefreshApp);
    on<SetupShizuku>(_onSetupShizuku);
    on<ToggleAppSelected>(_onToggleAppSelected);
    on<ClearSelection>(_onClearSelection);
    on<FilterChanged>(_onFilterChanged);
    on<SearchChanged>(_onSearchChanged);
    on<DetectCapabilities>(_onDetectCapabilities);
  }

  Future<void> _onDetectCapabilities(
    DetectCapabilities event, Emitter<PermissionState> emit) async {
    _caps = await _channel.detectCapabilities();
    emit(state.copyWith(capabilities: _caps));
  }

  Future<void> _onLoadApps(
    LoadApps event, Emitter<PermissionState> emit) async {
    emit(state.copyWith(status: PermissionStatus.loading));
    try {
      // Detect capabilities first
      _caps ??= await _channel.detectCapabilities();

      final apps = await _channel.getInstalledApps(
        includeSystem: state.showSystemApps);

      emit(state.copyWith(
        status: PermissionStatus.loaded,
        apps: apps,
        capabilities: _caps,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PermissionStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onToggleLocation(
    ToggleLocation event, Emitter<PermissionState> emit) async {
    // Optimistically set loading state on this app
    emit(state.copyWith(
      apps: state.apps.map((a) =>
        a.packageName == event.packageName
          ? a.copyWith(isLoading: true) : a
      ).toList(),
    ));

    final caps = _caps ?? await _channel.detectCapabilities();
    final result = await _channel.toggleLocation(
      packageName: event.packageName,
      allow: event.allow,
      caps: caps,
    );

    if (result.requiresFallback) {
      // Direct control unavailable — open settings and wait
      await _channel.openAppSettings(event.packageName);
      // Refresh after short delay (user might have changed it manually)
      await Future.delayed(const Duration(seconds: 2));
    }

    // Refresh the actual state from Android
    final updatedApps = await Future.wait(state.apps.map((app) async {
      if (app.packageName != event.packageName) return app;
      return _channel.refreshApp(app);
    }));

    emit(state.copyWith(
      apps: updatedApps,
      lastToggleResult: result,
    ));
  }

  Future<void> _onBatchToggle(
    BatchToggle event, Emitter<PermissionState> emit) async {
    final selected = state.apps.where((a) => a.isSelected).map((a) => a.packageName).toList();
    if (selected.isEmpty) return;

    emit(state.copyWith(status: PermissionStatus.batchProcessing,
      apps: state.apps.map((a) =>
        a.isSelected ? a.copyWith(isLoading: true) : a).toList()));

    final caps = _caps ?? await _channel.detectCapabilities();
    await _channel.batchToggle(
      packageNames: selected, allow: event.allow, caps: caps);

    // Refresh all affected apps
    final updatedApps = await Future.wait(state.apps.map((app) async {
      if (!app.isSelected) return app;
      return (await _channel.refreshApp(app)).copyWith(isSelected: false);
    }));

    emit(state.copyWith(
      status: PermissionStatus.loaded,
      apps: updatedApps,
    ));
  }

  Future<void> _onRefreshApp(
    RefreshApp event, Emitter<PermissionState> emit) async {
    final appIndex = state.apps.indexWhere(
      (a) => a.packageName == event.packageName);
    if (appIndex == -1) return;

    final refreshed = await _channel.refreshApp(state.apps[appIndex]);
    final updated = List<AppInfo>.from(state.apps);
    updated[appIndex] = refreshed;
    emit(state.copyWith(apps: updated));
  }

  Future<void> _onSetupShizuku(
    SetupShizuku event, Emitter<PermissionState> emit) async {
    emit(state.copyWith(shizukuSetupStep: ShizukuSetupStep.requesting));
    final granted = await _channel.requestShizukuPermission();
    if (granted) {
      _caps = await _channel.detectCapabilities();
      emit(state.copyWith(
        capabilities: _caps,
        shizukuSetupStep: ShizukuSetupStep.complete,
      ));
    } else {
      emit(state.copyWith(shizukuSetupStep: ShizukuSetupStep.denied));
    }
  }

  void _onToggleAppSelected(
    ToggleAppSelected event, Emitter<PermissionState> emit) {
    emit(state.copyWith(
      apps: state.apps.map((a) =>
        a.packageName == event.packageName
          ? a.copyWith(isSelected: !a.isSelected) : a
      ).toList(),
    ));
  }

  void _onClearSelection(ClearSelection event, Emitter<PermissionState> emit) {
    emit(state.copyWith(
      apps: state.apps.map((a) => a.copyWith(isSelected: false)).toList()));
  }

  void _onFilterChanged(FilterChanged event, Emitter<PermissionState> emit) {
    emit(state.copyWith(filter: event.filter));
  }

  void _onSearchChanged(SearchChanged event, Emitter<PermissionState> emit) {
    emit(state.copyWith(searchQuery: event.query));
  }
}
```

## lib/features/permission_manager/presentation/bloc/permission_event.dart

```dart
abstract class PermissionEvent {}

class LoadApps extends PermissionEvent {}
class DetectCapabilities extends PermissionEvent {}

class ToggleLocation extends PermissionEvent {
  final String packageName;
  final bool allow;
  ToggleLocation({required this.packageName, required this.allow});
}

class BatchToggle extends PermissionEvent {
  final bool allow;
  BatchToggle({required this.allow});
}

class RefreshApp extends PermissionEvent {
  final String packageName;
  RefreshApp(this.packageName);
}

class SetupShizuku extends PermissionEvent {}

class ToggleAppSelected extends PermissionEvent {
  final String packageName;
  ToggleAppSelected(this.packageName);
}

class ClearSelection extends PermissionEvent {}

class FilterChanged extends PermissionEvent {
  final PermissionFilter filter;
  FilterChanged(this.filter);
}

class SearchChanged extends PermissionEvent {
  final String query;
  SearchChanged(this.query);
}

enum PermissionFilter { all, withLocation, withoutLocation, background, activeNow }
```

## lib/features/permission_manager/presentation/bloc/permission_state.dart

```dart
import '../../data/channel/permission_channel.dart';
import '../../domain/entity/app_info.dart';
import 'permission_event.dart';

enum PermissionStatus { initial, loading, loaded, error, batchProcessing }
enum ShizukuSetupStep { none, requesting, complete, denied }

class PermissionState {
  final PermissionStatus status;
  final List<AppInfo> apps;
  final DeviceCapabilities? capabilities;
  final ToggleResult? lastToggleResult;
  final String? errorMessage;
  final PermissionFilter filter;
  final String searchQuery;
  final bool showSystemApps;
  final ShizukuSetupStep shizukuSetupStep;

  const PermissionState({
    this.status = PermissionStatus.initial,
    this.apps = const [],
    this.capabilities,
    this.lastToggleResult,
    this.errorMessage,
    this.filter = PermissionFilter.all,
    this.searchQuery = '',
    this.showSystemApps = false,
    this.shizukuSetupStep = ShizukuSetupStep.none,
  });

  List<AppInfo> get filteredApps {
    var result = apps;

    // Search
    if (searchQuery.isNotEmpty) {
      result = result.where((a) =>
        a.appName.toLowerCase().contains(searchQuery.toLowerCase()) ||
        a.packageName.toLowerCase().contains(searchQuery.toLowerCase())
      ).toList();
    }

    // Filter
    switch (filter) {
      case PermissionFilter.withLocation:
        result = result.where((a) => a.hasAnyLocation && !a.isEffectivelyBlocked).toList();
        break;
      case PermissionFilter.withoutLocation:
        result = result.where((a) => !a.hasAnyLocation || a.isEffectivelyBlocked).toList();
        break;
      case PermissionFilter.background:
        result = result.where((a) => a.hasBackgroundLocation).toList();
        break;
      case PermissionFilter.activeNow:
        result = result.where((a) => a.isActiveNow).toList();
        break;
      case PermissionFilter.all:
        break;
    }

    return result;
  }

  List<AppInfo> get selectedApps => apps.where((a) => a.isSelected).toList();
  int get withLocationCount => apps.where((a) => a.hasAnyLocation && !a.isEffectivelyBlocked).length;
  bool get hasSelection => apps.any((a) => a.isSelected);

  PermissionState copyWith({
    PermissionStatus? status,
    List<AppInfo>? apps,
    DeviceCapabilities? capabilities,
    ToggleResult? lastToggleResult,
    String? errorMessage,
    PermissionFilter? filter,
    String? searchQuery,
    bool? showSystemApps,
    ShizukuSetupStep? shizukuSetupStep,
  }) => PermissionState(
    status: status ?? this.status,
    apps: apps ?? this.apps,
    capabilities: capabilities ?? this.capabilities,
    lastToggleResult: lastToggleResult ?? this.lastToggleResult,
    errorMessage: errorMessage ?? errorMessage,
    filter: filter ?? this.filter,
    searchQuery: searchQuery ?? this.searchQuery,
    showSystemApps: showSystemApps ?? this.showSystemApps,
    shizukuSetupStep: shizukuSetupStep ?? this.shizukuSetupStep,
  );
}
```

## lib/features/permission_manager/presentation/screen/permission_list_screen.dart

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/permission_bloc.dart';
import '../bloc/permission_event.dart';
import '../bloc/permission_state.dart';
import '../widget/app_permission_tile.dart';
import '../widget/permission_method_banner.dart';
import '../widget/shizuku_setup_sheet.dart';
import '../../data/channel/permission_channel.dart';

class PermissionListScreen extends StatefulWidget {
  const PermissionListScreen({super.key});
  @override State<PermissionListScreen> createState() => _PermissionListScreenState();
}

class _PermissionListScreenState extends State<PermissionListScreen>
    with WidgetsBindingObserver {
  String? _pendingRefreshPackage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<PermissionBloc>().add(LoadApps());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Fires when user returns from system settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingRefreshPackage != null) {
      context.read<PermissionBloc>().add(RefreshApp(_pendingRefreshPackage!));
      _pendingRefreshPackage = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PermissionBloc, PermissionState>(
      listener: _handleStateChanges,
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              _buildSliverAppBar(context, state),
            ],
            body: Column(
              children: [
                // Method banner — shows how permissions are being controlled
                if (state.capabilities != null)
                  PermissionMethodBanner(
                    capabilities: state.capabilities!,
                    onSetupShizuku: () => _showShizukuSetup(context),
                  ),

                // Batch action bar — slides up when apps are selected
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: state.hasSelection
                    ? _buildBatchActionBar(context, state)
                    : const SizedBox.shrink(),
                ),

                // Main list
                Expanded(child: _buildList(context, state)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(BuildContext context, PermissionState state) {
    return SliverAppBar(
      backgroundColor: const Color(0xFF0F0F0F),
      floating: true,
      pinned: false,
      title: Row(children: [
        const Icon(Icons.shield_rounded, color: Color(0xFF2563EB), size: 24),
        const SizedBox(width: 8),
        const Text('PermGuard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        if (state.status == PermissionStatus.loaded) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.2),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '${state.withLocationCount} active',
              style: const TextStyle(
                color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded, color: Colors.white),
          onPressed: () => _showSearch(context),
        ),
        IconButton(
          icon: const Icon(Icons.tune_rounded, color: Colors.white),
          onPressed: () => _showFilterSheet(context, state),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () => context.read<PermissionBloc>().add(LoadApps()),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, PermissionState state) {
    if (state.status == PermissionStatus.loading) {
      return _buildShimmer();
    }

    if (state.status == PermissionStatus.error) {
      return _buildError(context, state.errorMessage ?? 'Unknown error');
    }

    final apps = state.filteredApps;

    if (apps.isEmpty) {
      return _buildEmpty(state);
    }

    return RefreshIndicator(
      onRefresh: () async => context.read<PermissionBloc>().add(LoadApps()),
      color: const Color(0xFF2563EB),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.separated(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 32),
        itemCount: apps.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final app = apps[index];
          return AppPermissionTile(
            app: app,
            canDirectlyControl: state.capabilities?.canDirectlyControl ?? false,
            onToggle: (allow) {
              if (!(state.capabilities?.canDirectlyControl ?? false)) {
                _pendingRefreshPackage = app.packageName;
              }
              context.read<PermissionBloc>().add(
                ToggleLocation(packageName: app.packageName, allow: allow));
            },
            onLongPress: () => context.read<PermissionBloc>().add(
              ToggleAppSelected(app.packageName)),
            isMultiSelectMode: state.hasSelection,
          );
        },
      ),
    );
  }

  Widget _buildBatchActionBar(BuildContext context, PermissionState state) {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Text('${state.selectedApps.length} selected',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        const Spacer(),
        TextButton.icon(
          onPressed: () => context.read<PermissionBloc>().add(BatchToggle(allow: true)),
          icon: const Icon(Icons.location_on_rounded, color: Color(0xFF22C55E), size: 18),
          label: const Text('Allow All', style: TextStyle(color: Color(0xFF22C55E))),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => context.read<PermissionBloc>().add(BatchToggle(allow: false)),
          icon: const Icon(Icons.location_off_rounded, color: Color(0xFFEF4444), size: 18),
          label: const Text('Revoke All', style: TextStyle(color: Color(0xFFEF4444))),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white54),
          onPressed: () => context.read<PermissionBloc>().add(ClearSelection()),
        ),
      ]),
    );
  }

  void _handleStateChanges(BuildContext context, PermissionState state) {
    final result = state.lastToggleResult;
    if (result == null) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 18),
          const SizedBox(width: 8),
          Text(result.message, style: const TextStyle(color: Colors.white)),
        ]),
        backgroundColor: const Color(0xFF262626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    } else if (result.requiresShizuku) {
      _showShizukuSetup(context);
    }
  }

  void _showShizukuSetup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<PermissionBloc>(),
        child: const ShizukuSetupSheet(),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _AppSearchDelegate(context.read<PermissionBloc>()),
    );
  }

  void _showFilterSheet(BuildContext context, PermissionState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FilterSheet(
        currentFilter: state.filter,
        onFilterSelected: (f) {
          context.read<PermissionBloc>().add(FilterChanged(f));
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => _ShimmerTile(),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 64),
      const SizedBox(height: 16),
      Text('Failed to load apps',
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(message,
        style: const TextStyle(color: Colors.white54, fontSize: 13),
        textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () => context.read<PermissionBloc>().add(LoadApps()),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Retry'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]));
  }

  Widget _buildEmpty(PermissionState state) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.shield_rounded, color: Color(0xFF22C55E), size: 72),
      const SizedBox(height: 16),
      const Text('All Clear!',
        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('No apps match the current filter',
        style: TextStyle(color: Colors.white54, fontSize: 14)),
    ]));
  }
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _ShimmerTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  final PermissionFilter currentFilter;
  final ValueChanged<PermissionFilter> onFilterSelected;

  const _FilterSheet({required this.currentFilter, required this.onFilterSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.white24, borderRadius: BorderRadius.circular(99)),
        )),
        const SizedBox(height: 20),
        const Text('Filter Apps',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...PermissionFilter.values.map((f) {
          final labels = {
            PermissionFilter.all: ('All Apps', Icons.apps_rounded),
            PermissionFilter.withLocation: ('Has Location Access', Icons.location_on_rounded),
            PermissionFilter.withoutLocation: ('No Location Access', Icons.location_off_rounded),
            PermissionFilter.background: ('Background Location', Icons.location_searching_rounded),
            PermissionFilter.activeNow: ('Active Right Now', Icons.sensors_rounded),
          };
          final (label, icon) = labels[f]!;
          final isSelected = f == currentFilter;
          return ListTile(
            leading: Icon(icon,
              color: isSelected ? const Color(0xFF2563EB) : Colors.white54),
            title: Text(label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF60A5FA) : Colors.white,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
            trailing: isSelected
              ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB)) : null,
            onTap: () => onFilterSelected(f),
          );
        }),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _AppSearchDelegate extends SearchDelegate<String> {
  final PermissionBloc bloc;
  _AppSearchDelegate(this.bloc);

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1A1A1A)),
    inputDecorationTheme: const InputDecorationTheme(
      hintStyle: TextStyle(color: Colors.white38)),
  );

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) =>
    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) {
    bloc.add(SearchChanged(query));
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    bloc.add(SearchChanged(query));
    return const SizedBox.shrink();
  }
}
```

## lib/features/permission_manager/presentation/widget/app_permission_tile.dart

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../domain/entity/app_info.dart';

class AppPermissionTile extends StatelessWidget {
  final AppInfo app;
  final bool canDirectlyControl;
  final ValueChanged<bool> onToggle;
  final VoidCallback onLongPress;
  final bool isMultiSelectMode;

  const AppPermissionTile({
    super.key,
    required this.app,
    required this.canDirectlyControl,
    required this.onToggle,
    required this.onLongPress,
    required this.isMultiSelectMode,
  });

  @override
  Widget build(BuildContext context) {
    final isGranted = app.hasAnyLocation && !app.isEffectivelyBlocked;

    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: app.isSelected
            ? const Color(0xFF2563EB).withOpacity(0.15)
            : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: app.isSelected
              ? const Color(0xFF2563EB).withOpacity(0.5)
              : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            // Multi-select checkbox
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: isMultiSelectMode
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: app.isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                        border: Border.all(
                          color: app.isSelected ? const Color(0xFF2563EB) : Colors.white38,
                          width: 2),
                      ),
                      child: app.isSelected
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                        : null,
                    ),
                  )
                : const SizedBox.shrink(),
            ),

            // App Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: app.iconBytes != null
                ? Image.memory(app.iconBytes!, width: 44, height: 44, fit: BoxFit.cover)
                : Container(
                    width: 44, height: 44,
                    color: const Color(0xFF262626),
                    child: const Icon(Icons.android_rounded, color: Colors.white38, size: 24)),
            ),
            const SizedBox(width: 12),

            // App info
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.appName,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  // Active indicator
                  if (app.isActiveNow) ...[
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xFF22C55E)),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    app.isActiveNow ? 'Active now' : app.lastAccessLabel,
                    style: TextStyle(
                      color: app.isActiveNow
                        ? const Color(0xFF22C55E) : Colors.white38,
                      fontSize: 11),
                  ),
                  if (app.hasBackgroundLocation) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Background',
                        style: TextStyle(
                          color: Color(0xFFF59E0B), fontSize: 9,
                          fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
              ],
            )),

            // Toggle or loading
            if (app.isLoading)
              const SizedBox(
                width: 36, height: 20,
                child: Center(child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF2563EB)),
                )),
              )
            else
              GestureDetector(
                onTap: () => onToggle(!isGranted),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 46, height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: isGranted
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF374151),
                    // Glow when active
                    boxShadow: isGranted ? [
                      BoxShadow(
                        color: const Color(0xFF22C55E).withOpacity(0.4),
                        blurRadius: 8, spreadRadius: 0)
                    ] : [],
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: isGranted ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 20, height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
```

## lib/features/permission_manager/presentation/widget/permission_method_banner.dart

```dart
import 'package:flutter/material.dart';
import '../../data/channel/permission_channel.dart';

class PermissionMethodBanner extends StatelessWidget {
  final DeviceCapabilities capabilities;
  final VoidCallback onSetupShizuku;

  const PermissionMethodBanner({
    super.key, required this.capabilities, required this.onSetupShizuku});

  @override
  Widget build(BuildContext context) {
    if (capabilities.shizukuPermissionGranted) {
      return _buildBanner(
        icon: Icons.flash_on_rounded,
        label: 'Full Control via Shizuku',
        sublabel: 'Permissions change instantly',
        color: const Color(0xFF22C55E),
        bgColor: const Color(0xFF22C55E).withOpacity(0.1),
      );
    }

    if (capabilities.appOpsAvailable) {
      return _buildBanner(
        icon: Icons.tune_rounded,
        label: 'Direct Control via AppOps',
        sublabel: 'Changes apply immediately',
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFF2563EB).withOpacity(0.1),
      );
    }

    if (capabilities.shizukuInstalled && !capabilities.shizukuRunning) {
      return _buildBanner(
        icon: Icons.info_outline_rounded,
        label: 'Shizuku found but not running',
        sublabel: 'Tap to enable full control',
        color: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFF59E0B).withOpacity(0.1),
        action: TextButton(
          onPressed: onSetupShizuku,
          child: const Text('Enable', style: TextStyle(color: Color(0xFFF59E0B))),
        ),
      );
    }

    return _buildBanner(
      icon: Icons.settings_rounded,
      label: 'Enable Shizuku for direct control',
      sublabel: 'Currently opening settings to change each app',
      color: Colors.white38,
      bgColor: const Color(0xFF1A1A1A),
      action: TextButton(
        onPressed: onSetupShizuku,
        child: const Text('Setup', style: TextStyle(color: Color(0xFF60A5FA))),
      ),
    );
  }

  Widget _buildBanner({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required Color bgColor,
    Widget? action,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            Text(sublabel,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        )),
        if (action != null) action,
      ]),
    );
  }
}
```

## lib/features/permission_manager/presentation/widget/shizuku_setup_sheet.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/permission_bloc.dart';
import '../bloc/permission_event.dart';

class ShizukuSetupSheet extends StatelessWidget {
  const ShizukuSetupSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.white24, borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(height: 20),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.15),
            shape: BoxShape.circle),
          child: const Icon(Icons.flash_on_rounded,
            color: Color(0xFF60A5FA), size: 32),
        ),
        const SizedBox(height: 16),
        const Text('Enable Full Permission Control',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'Shizuku lets PermGuard change permissions instantly without opening settings for each app.',
          style: TextStyle(color: Colors.white60, fontSize: 14),
          textAlign: TextAlign.center),
        const SizedBox(height: 24),
        _buildStep('1', 'Install Shizuku from Play Store', Icons.download_rounded),
        _buildStep('2', 'Enable wireless debugging in Developer Options', Icons.developer_mode_rounded),
        _buildStep('3', 'Open Shizuku and tap "Start via Wireless Debugging"', Icons.play_arrow_rounded),
        _buildStep('4', 'Return here and tap "Enable Shizuku"', Icons.check_circle_rounded),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<PermissionBloc>().add(SetupShizuku());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Enable Shizuku', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip for now', style: TextStyle(color: Colors.white38)),
        ),
      ]),
    );
  }

  Widget _buildStep(String num, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.2),
            shape: BoxShape.circle),
          child: Center(child: Text(num,
            style: const TextStyle(
              color: Color(0xFF60A5FA), fontSize: 13, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 12),
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
          style: const TextStyle(color: Colors.white70, fontSize: 13))),
      ]),
    );
  }
}
```

---

# pubspec.yaml additions

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^8.1.4
  equatable: ^2.0.5

# Add Shizuku to android/app/build.gradle.kts:
# implementation("dev.rikka.shizuku:api:13.1.5")
# implementation("dev.rikka.shizuku:provider:13.1.5")
```

---

# FINAL INSTRUCTIONS

1. **Write every file completely.** Every class, every method, every import.

2. **The three paths must all be wired** — AppOps via reflection (Path 3) fires first, Shizuku (Path 2) is tried if AppOps is blocked, fallback to settings-deep-link only as last resort.

3. **AppOps reflection** — the `getSetModeMethod()` in `AppOpsPermissionManager.kt` uses the hidden API `AppOpsManager.setMode(int, int, String, int)`. This works on MIUI, ColorOS, OxygenOS, and some stock Android ROMs. It WILL throw SecurityException on hardened ROMs — catch it and return false.

4. **Shizuku pm revoke** — runs `pm revoke <package> <permission>` as ADB shell. This is identical to running `adb shell pm revoke` from a computer. It works on all Android versions 6+ without root once Shizuku is running.

5. **After ANY toggle** — always re-read the actual state via `getPermissionState()` and update the UI. Never trust the toggle's optimistic state alone.

6. **The UI toggle must show the real effective state** — use `appOpsMode` field (0=allowed, 1=ignored) in addition to the raw PackageManager permission check, because AppOps can block a permission even if PackageManager says it's granted.

7. **Batch operations** — process sequentially, not in parallel, to avoid race conditions with the permission system.

8. **Package name:** com.permguard.app
