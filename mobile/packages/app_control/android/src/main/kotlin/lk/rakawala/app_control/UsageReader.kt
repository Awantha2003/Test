package lk.rakawala.app_control

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import java.util.Calendar

object UsageReader {
    // Raw values of ACTIVITY_RESUMED / ACTIVITY_PAUSED (same as the older MOVE_TO_FOREGROUND / BACKGROUND).
    private const val RESUMED = 1
    private const val PAUSED = 2

    fun hasUsageAccess(ctx: Context): Boolean {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun startOfToday(): Long = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    /** Foreground time per package since local midnight, in milliseconds (event-accurate). */
    fun usageToday(ctx: Context): Map<String, Long> {
        if (!hasUsageAccess(ctx)) return emptyMap()
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val start = startOfToday()
        val end = System.currentTimeMillis()
        val events = usm.queryEvents(start, end)
        val ev = UsageEvents.Event()
        val openSince = HashMap<String, Long>()
        val total = HashMap<String, Long>()
        while (events.hasNextEvent()) {
            events.getNextEvent(ev)
            val pkg = ev.packageName ?: continue
            when (ev.eventType) {
                RESUMED -> openSince[pkg] = ev.timeStamp
                PAUSED -> openSince.remove(pkg)?.let { total[pkg] = (total[pkg] ?: 0L) + (ev.timeStamp - it) }
            }
        }
        // Still in the foreground right now.
        for ((pkg, since) in openSince) total[pkg] = (total[pkg] ?: 0L) + (end - since)
        total.remove(ctx.packageName)
        return total
    }

    /** Apps the child can open from the launcher. */
    fun installedApps(ctx: Context): List<Map<String, String>> {
        val pm = ctx.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val list = if (Build.VERSION.SDK_INT >= 33) {
            pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(intent, 0)
        }
        return list.map { it.activityInfo.packageName to it.loadLabel(pm).toString() }
            .filter { it.first != ctx.packageName }
            .distinctBy { it.first }
            .map { mapOf("pkg" to it.first, "name" to it.second) }
    }
}
