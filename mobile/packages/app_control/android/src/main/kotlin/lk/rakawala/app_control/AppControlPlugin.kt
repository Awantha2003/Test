package lk.rakawala.app_control

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Method channel used by both the UI isolate and the background location service isolate. */
class AppControlPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var ctx: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ctx = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "lk.rakawala/app_control")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "status" -> result.success(mapOf("usageAccess" to UsageReader.hasUsageAccess(ctx), "accessibility" to isBlockerEnabled()))
                "openUsageAccessSettings" -> { open(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)); result.success(null) }
                "openAccessibilitySettings" -> { open(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)); result.success(null) }
                "installedApps" -> result.success(UsageReader.installedApps(ctx))
                "usageToday" -> result.success(UsageReader.usageToday(ctx))
                "setRules" -> { RuleStore.save(ctx, call.arguments as? String ?: "{}"); result.success(null) }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("app_control", e.message, null)
        }
    }

    private fun open(intent: Intent) {
        ctx.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun isBlockerEnabled(): Boolean {
        val me = ComponentName(ctx, AppBlockerService::class.java)
        val enabled = Settings.Secure.getString(ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == me }
    }
}
