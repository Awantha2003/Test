import lk.rakawala.app_control.RuleEngine
import java.util.Calendar

fun at(day: Int, h: Int, m: Int): Calendar = Calendar.getInstance().apply { clear(); set(2026, Calendar.OCTOBER, day, h, m) } // Oct 12 2026 = Monday

var failures = 0
fun check(name: String, actual: Any?, expected: Any?) {
    if (actual != expected) { failures++; println("FAIL $name: expected=$expected actual=$actual") } else println("ok   $name")
}

fun main() {
    val json = """
      {"apps":{"tiktok":{"mode":"block"},"youtube":{"mode":"limit","limitMin":60},"maths":{"mode":"always"}},
       "schedules":[{"id":"school","label":"School time","days":["mon","tue","wed","thu","fri"],"start":"07:30","end":"13:30","active":true},
                    {"id":"bed","label":"Bedtime","days":["sun","mon","tue","wed","thu"],"start":"21:30","end":"06:00","active":true}],
       "dailyLimitMin":180}"""
    val e = RuleEngine(json)
    check("blocked app", e.blockReason("tiktok", at(17, 20, 0), 0, 0), "Blocked by your family")
    check("school time pauses normal app", e.blockReason("whatsapp", at(12, 9, 0), 0, 0), "School time (07:30–13:30)")
    check("always app during school", e.blockReason("maths", at(12, 9, 0), 0, 0), null)
    check("school end exclusive", e.blockReason("whatsapp", at(12, 13, 30), 0, 0), null)
    check("saturday no school", e.blockReason("whatsapp", at(17, 9, 0), 0, 0), null)
    check("bedtime monday night", e.blockReason("whatsapp", at(12, 22, 0), 0, 0), "Bedtime (21:30–06:00)")
    check("bedtime tuesday 05:59", e.blockReason("whatsapp", at(13, 5, 59), 0, 0), "Bedtime (21:30–06:00)")
    check("bedtime ends 06:00", e.blockReason("whatsapp", at(13, 6, 0), 0, 0), null)
    check("friday night not listed", e.blockReason("whatsapp", at(16, 23, 0), 0, 0), null)
    check("sat 02:00 belongs to friday", e.blockReason("whatsapp", at(17, 2, 0), 0, 0), null)
    check("mon 02:00 belongs to sunday", e.blockReason("whatsapp", at(12, 2, 0), 0, 0), "Bedtime (21:30–06:00)")
    check("limit not reached", e.blockReason("youtube", at(12, 16, 0), 59, 0), null)
    check("limit reached", e.blockReason("youtube", at(12, 16, 0), 60, 0), "Daily limit of 60 min reached")
    check("total limit", e.blockReason("whatsapp", at(12, 16, 0), 0, 180), "Daily screen time of 180 min used up")
    check("always ignores total", e.blockReason("maths", at(12, 16, 0), 0, 500), null)
    check("empty rules", RuleEngine(null).blockReason("tiktok", at(12, 9, 0), 0, 0), null)
    check("malformed json never blocks", RuleEngine("{not json").blockReason("tiktok", at(12, 9, 0), 0, 0), null)
    check("isEmpty", RuleEngine("{}").isEmpty, true)
    println(if (failures == 0) "ALL PARITY CHECKS PASSED" else "$failures FAILED")
}
