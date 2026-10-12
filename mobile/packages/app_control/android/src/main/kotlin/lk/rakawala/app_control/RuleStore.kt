package lk.rakawala.app_control

import android.content.Context

/** Rules are stored natively so the blocking service works even when Flutter isn't running. */
object RuleStore {
    private const val PREFS = "rakawala_app_control"
    private const val KEY = "rules_json"

    fun save(ctx: Context, json: String) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).apply()
    }

    fun load(ctx: Context): String? = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
}
