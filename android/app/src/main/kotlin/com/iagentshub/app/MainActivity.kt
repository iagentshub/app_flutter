package com.iagentshub.app

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.iagentshub.app/app_icon"
    private val iconNames = listOf(
        "default",
        "agentCoordinator",
        "coordinatorWhiteOnRed",
        "coordinatorRedOnBlack",
        "coordinatorBlackOnRed",
        "coordinatorRedOnWhite",
        "iaInterRedOnBlack",
        "iaInterBlackOnRed",
        "iaInterRedOnWhite",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            if (call.method != "setIcon") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val requestedName = call.argument<String>("name") ?: "default"
            if (!iconNames.contains(requestedName)) {
                result.error("UNKNOWN_ICON", "Icono desconocido: $requestedName", null)
                return@setMethodCallHandler
            }

            try {
                setLauncherIcon(requestedName)
                result.success(null)
            } catch (error: Exception) {
                result.error("ICON_CHANGE_FAILED", error.message, null)
            }
        }
    }

    private fun setLauncherIcon(selectedName: String) {
        val selectedComponent = ComponentName(
            this,
            "$packageName.MainActivity.$selectedName",
        )
        packageManager.setComponentEnabledSetting(
            selectedComponent,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )

        iconNames
            .filter { it != selectedName }
            .forEach { iconName ->
                packageManager.setComponentEnabledSetting(
                    ComponentName(this, "$packageName.MainActivity.$iconName"),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
    }
}
