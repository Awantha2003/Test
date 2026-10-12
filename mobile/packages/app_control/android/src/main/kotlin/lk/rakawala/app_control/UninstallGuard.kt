package lk.rakawala.app_control

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * "Uninstall protection": while this device-admin receiver is active, Android won't let
 * Rakawala be uninstalled until protection is switched off in Settings first. It requests
 * no admin policies at all (no wipe, no lock, no password rules). Switching it off is
 * always possible, but it's recorded and reported so guardians are alerted.
 */
class UninstallGuard : DeviceAdminReceiver() {
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence =
        "Turning this off lets Rakawala be removed. Your parent will be notified."

    override fun onDisabled(context: Context, intent: Intent) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putLong(KEY_DISABLED_AT, System.currentTimeMillis()).apply()
    }

    override fun onEnabled(context: Context, intent: Intent) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY_DISABLED_AT).apply()
    }

    companion object {
        private const val PREFS = "rakawala_app_control"
        private const val KEY_DISABLED_AT = "uninstall_guard_disabled_at"

        fun component(ctx: Context) = ComponentName(ctx, UninstallGuard::class.java)

        fun isActive(ctx: Context): Boolean =
            (ctx.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager).isAdminActive(component(ctx))

        fun disabledAt(ctx: Context): Long? =
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(KEY_DISABLED_AT, 0L).takeIf { it > 0 }

        fun activationIntent(ctx: Context): Intent =
            Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, component(ctx))
                .putExtra(
                    DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                    "Keeps Rakawala on this phone so your family can find you in an emergency. " +
                        "It can't read your data, lock or erase the phone.",
                )
    }
}
