package lk.rakawala.app_control

import org.json.JSONObject
import java.util.Calendar

/**
 * Kotlin mirror of lib/app_rules.dart (the unit-tested source of truth). Keep both in sync.
 */
class RuleEngine(json: String?) {
    data class Rule(val mode: String, val limitMin: Int)
    data class Window(val label: String, val days: Set<String>, val start: String, val end: String, val active: Boolean)

    val apps = HashMap<String, Rule>()
    val windows = ArrayList<Window>()
    var dailyLimitMin = 0
        private set

    init {
        if (!json.isNullOrBlank()) {
            try {
                val o = JSONObject(json)
                o.optJSONObject("apps")?.let { a ->
                    for (pkg in a.keys()) {
                        val r = a.optJSONObject(pkg) ?: continue
                        apps[pkg] = Rule(r.optString("mode", "allow"), r.optInt("limitMin", 60))
                    }
                }
                o.optJSONArray("schedules")?.let { arr ->
                    for (i in 0 until arr.length()) {
                        val w = arr.optJSONObject(i) ?: continue
                        val days = HashSet<String>()
                        w.optJSONArray("days")?.let { d -> for (j in 0 until d.length()) days.add(d.optString(j)) }
                        windows.add(Window(w.optString("label", "Schedule"), days, w.optString("start", "00:00"), w.optString("end", "00:00"), w.optBoolean("active", true)))
                    }
                }
                dailyLimitMin = o.optInt("dailyLimitMin", 0)
            } catch (_: Exception) {
                // Malformed rules must never lock the phone: treat as "no rules".
                apps.clear(); windows.clear(); dailyLimitMin = 0
            }
        }
    }

    /** Returns null when allowed, otherwise the reason shown to the child. */
    fun blockReason(pkg: String, now: Calendar, usedMin: Int, totalMin: Int): String? {
        val rule = apps[pkg] ?: Rule("allow", 60)
        if (rule.mode == "block") return "Blocked by your family"
        if (rule.mode == "always") return null
        for (w in windows) if (isActive(w, now)) return "${w.label} (${w.start}–${w.end})"
        if (rule.mode == "limit" && usedMin >= rule.limitMin) return "Daily limit of ${rule.limitMin} min reached"
        if (dailyLimitMin > 0 && totalMin >= dailyLimitMin) return "Daily screen time of $dailyLimitMin min used up"
        return null
    }

    val isEmpty: Boolean get() = apps.isEmpty() && windows.none { it.active } && dailyLimitMin <= 0

    companion object {
        private val DAYS = arrayOf("sun", "mon", "tue", "wed", "thu", "fri", "sat") // Calendar.DAY_OF_WEEK - 1

        private fun minutes(hhmm: String): Int {
            val p = hhmm.split(":")
            return (p.getOrNull(0)?.toIntOrNull() ?: 0) * 60 + (p.getOrNull(1)?.toIntOrNull() ?: 0)
        }

        fun isActive(w: Window, now: Calendar): Boolean {
            if (!w.active) return false
            val s = minutes(w.start)
            val e = minutes(w.end)
            if (s == e) return false
            val t = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
            val dow = now.get(Calendar.DAY_OF_WEEK) - 1
            val today = DAYS[dow]
            val yesterday = DAYS[(dow + 6) % 7]
            return if (s < e) w.days.contains(today) && t >= s && t < e
            else (w.days.contains(today) && t >= s) || (w.days.contains(yesterday) && t < e)
        }
    }
}
