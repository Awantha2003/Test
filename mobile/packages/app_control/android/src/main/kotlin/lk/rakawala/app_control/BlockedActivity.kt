package lk.rakawala.app_control

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/** Friendly full-screen notice shown instead of a paused app. Plain views: no Flutter engine needed. */
class BlockedActivity : Activity() {
    companion object {
        const val EXTRA_APP = "app"
        const val EXTRA_REASON = "reason"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val app = intent.getStringExtra(EXTRA_APP) ?: "This app"
        val reason = intent.getStringExtra(EXTRA_REASON) ?: "Paused by your family"
        val dp = resources.displayMetrics.density

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding((32 * dp).toInt(), 0, (32 * dp).toInt(), 0)
            background = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(Color.parseColor("#1E3A8A"), Color.parseColor("#1D4ED8")))
        }
        fun label(s: String, size: Float, bold: Boolean = false, alpha: Float = 1f) = TextView(this).apply {
            text = s
            textSize = size
            setTextColor(Color.WHITE)
            this.alpha = alpha
            gravity = Gravity.CENTER
            if (bold) setTypeface(typeface, Typeface.BOLD)
            setPadding(0, (8 * dp).toInt(), 0, (8 * dp).toInt())
        }
        root.addView(label("⏸", 56f))
        root.addView(label("$app is paused", 24f, bold = true))
        root.addView(label(reason, 16f, alpha = 0.85f))
        root.addView(label("Your family set this in Rakawala. Calls, SMS and SOS always work.", 14f, alpha = 0.7f))
        root.addView(Button(this).apply {
            text = "OK"
            setOnClickListener { goHome() }
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = (24 * dp).toInt() }
        })
        setContentView(root)
    }

    private fun goHome() {
        startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        finish()
    }

    @Deprecated("Back always leaves to the home screen, never back into the paused app.")
    override fun onBackPressed() = goHome()
}
