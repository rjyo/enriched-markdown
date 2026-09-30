package com.swmansion.enriched.markdown.spans

import android.graphics.Color
import android.os.Build
import android.text.Spannable
import android.text.TextPaint
import android.text.style.CharacterStyle
import android.text.style.UpdateAppearance

/**
 * A host-supplied annotation: `[start, end)` in view-global offsets (text
 * segments' lengths summed in order). `active` paints it stronger.
 */
data class MarkedRange(
  val id: String,
  val start: Int,
  val end: Int,
  val active: Boolean,
)

/**
 * Paints a marked range with a tinted background and underline, mirroring
 * iOS's ENRMMarkedRanges. Marks are spans on the segment's text, so removing
 * one leaves the text exactly as rendered.
 */
class MarkSpan(
  val markId: String,
  private val color: Int,
  private val active: Boolean,
) : CharacterStyle(),
  UpdateAppearance {
  override fun updateDrawState(textPaint: TextPaint) {
    textPaint.bgColor = withAlpha(color, if (active) 0.30f else 0.16f)
    textPaint.isUnderlineText = true
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      textPaint.underlineColor = if (active) color else withAlpha(color, 0.7f)
    }
  }

  companion object {
    /** iOS's `systemGreenColor`, the fallback when no markColor is set. */
    private val DEFAULT_COLOR = Color.rgb(52, 199, 89)

    /**
     * Repaints the marks that fall inside one text segment whose first
     * character sits at `base`, replacing the segment's previous marks.
     */
    fun apply(
      text: Spannable,
      marks: List<MarkedRange>,
      base: Int,
      color: Int?,
    ) {
      text.getSpans(0, text.length, MarkSpan::class.java).forEach { text.removeSpan(it) }
      val inside = marks.filter { it.start >= base && it.end > it.start && it.end <= base + text.length }
      if (inside.isEmpty()) return
      val tint = color ?: DEFAULT_COLOR
      // Inactive first so the active mark's stronger paint wins where they overlap.
      (inside.filter { !it.active } + inside.filter { it.active }).forEach { mark ->
        text.setSpan(
          MarkSpan(mark.id, tint, mark.active),
          mark.start - base,
          mark.end - base,
          Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
      }
    }

    private fun withAlpha(
      color: Int,
      alpha: Float,
    ): Int = Color.argb((Color.alpha(color) * alpha).toInt(), Color.red(color), Color.green(color), Color.blue(color))
  }
}
