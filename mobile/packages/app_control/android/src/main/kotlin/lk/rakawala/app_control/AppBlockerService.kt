package lk.rakawala.app_control

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.provider.Telephony
import android.telecom.TelecomManager
import android.view.accessibility.AccessibilityEvent
import java.util.Calendar

/**
 * Enforces the guardian's app rules on the child's phone.
 *
 * It only listens for "which app is in front" (window-state changes). It never reads
 * screen content (canRetrieveWindowContent=false), typed text or notifications.
 * Phone, SMS, the launcher, Settings and Rakawala itself are never blocked, so the
 * child can always call for help.
 */
class AppBlockerService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private var currentPkg: String? = null
    private var rulesJson: String? = null
    private var engine = RuleEngine(null)
    private var usageCache: Map<String, Long> = emptyMap()
    private var usageAt = 0L
    private var essentials: Set<String> = emptySet()
    private var essentialsAt = 0L

    /** Re-check the app in front every minute, so a time limit or school time that starts mid-use applies. */
    private val recheck = object : Runnable {
        override fun run() {
            currentPkg?.let { check(it) }
            handler.postDelayed(this, 60_000)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        handler.postDelayed(recheck, 60_000)
    }

    override fun onDestroy() {
        handler.removeCallbacks(recheck)
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        currentPkg = pkg
        check(pkg)
    }

    override fun onInterrupt() {}

    private fun check(pkg: String) {
        if (pkg in essentialPackages()) return
        val json = RuleStore.load(this)
        if (json != rulesJson) {
            rulesJson = json
            engine = RuleEngine(json)
        }
        if (engine.isEmpty) return

        val usage = usageToday()
        val used = ((usage[pkg] ?: 0L) / 60_000).toInt()
        val total = (usage.filterKeys { it !in essentialPackages() && engine.apps[it]?.mode != "always" }.values.sum() / 60_000).toInt()
        val reason = engine.blockReason(pkg, Calendar.getInstance(), used, total) ?: return

        performGlobalAction(GLOBAL_ACTION_HOME)
        val label = try {
            packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
        } catch (_: Exception) { pkg }
        startActivity(
            Intent(this, BlockedActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION)
                .putExtra(BlockedActivity.EXTRA_APP, label)
                .putExtra(BlockedActivity.EXTRA_REASON, reason),
        )
        currentPkg = null
    }

    private fun usageToday(): Map<String, Long> {
        val now = System.currentTimeMillis()
        if (now - usageAt > 30_000) {
            usageCache = UsageReader.usageToday(this)
            usageAt = now
        }
        return usageCache
    }

    /** Packages that must always stay usable: calls, SMS, home screen, keyboard, settings, us. */
    private fun essentialPackages(): Set<String> {
        val now = System.currentTimeMillis()
        if (now - essentialsAt < 5 * 60_000 && essentials.isNotEmpty()) return essentials
        val set = hashSetOf(
            packageName, "android", "com.android.systemui", "com.android.settings",
            "com.android.phone", "com.android.server.telecom", "com.android.emergency",
            "com.google.android.dialer", "com.android.dialer",
            "com.google.android.permissioncontroller", "com.android.permissioncontroller",
            "com.google.android.packageinstaller", "com.android.packageinstaller",
        )
        try { (getSystemService(TELECOM_SERVICE) as TelecomManager).defaultDialerPackage?.let { set.add(it) } } catch (_: Exception) {}
        try { Telephony.Sms.getDefaultSmsPackage(this)?.let { set.add(it) } } catch (_: Exception) {}
        try {
            packageManager.resolveActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0)
                ?.activityInfo?.packageName?.let { set.add(it) }
        } catch (_: Exception) {}
        try {
            Settings.Secure.getString(contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
                ?.substringBefore('/')?.let { set.add(it) }
        } catch (_: Exception) {}
        essentials = set
        essentialsAt = now
        return set
    }
}
