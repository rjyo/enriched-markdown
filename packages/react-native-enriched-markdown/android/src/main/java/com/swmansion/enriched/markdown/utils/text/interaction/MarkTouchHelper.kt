package com.swmansion.enriched.markdown.utils.text.interaction

import android.text.Spanned
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.MarkSpan
import kotlin.math.abs

/**
 * Turns a tap on a marked range into [onMarkTap] instead of letting it reach
 * links or the RN touch handlers, like iOS. Unlike checkbox taps the gesture is
 * not swallowed: the text view still sees it, so a long press over a mark
 * selects text as usual. Only a short, still tap fires the mark.
 */
class MarkTouchHelper(
  private val textView: TextView,
) {
  var onMarkTap: ((markId: String) -> Unit)? = null

  private var touchDownX = 0f
  private var touchDownY = 0f
  private var touchDownTime = 0L
  private var pendingMarkId: String? = null
  private val touchSlop: Int by lazy { ViewConfiguration.get(textView.context).scaledTouchSlop }

  /** True while a touch that started on a mark may still become a tap. */
  val isTracking: Boolean get() = pendingMarkId != null

  /**
   * Feeds one event. Returns the tapped mark's id on the ACTION_UP that
   * completes a tap (after firing [onMarkTap]), else null.
   */
  fun onTouchEvent(event: MotionEvent): String? {
    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        pendingMarkId = if (onMarkTap == null) null else markIdAt(event)
        touchDownX = event.x
        touchDownY = event.y
        touchDownTime = event.eventTime
      }

      MotionEvent.ACTION_MOVE -> {
        if (pendingMarkId != null && isExceedingSlop(event)) pendingMarkId = null
      }

      MotionEvent.ACTION_UP -> {
        val markId = pendingMarkId ?: return null
        pendingMarkId = null
        val isTap =
          !isExceedingSlop(event) &&
            event.eventTime - touchDownTime < ViewConfiguration.getLongPressTimeout() &&
            !textView.hasSelection()
        if (!isTap) return null
        onMarkTap?.invoke(markId)
        return markId
      }

      MotionEvent.ACTION_CANCEL -> {
        pendingMarkId = null
      }
    }
    return null
  }

  private fun markIdAt(event: MotionEvent): String? {
    val text = textView.text as? Spanned ?: return null
    val layout = textView.layout ?: return null
    val x = event.x - textView.totalPaddingLeft + textView.scrollX
    val y = event.y - textView.totalPaddingTop + textView.scrollY
    if (y < 0f || y > layout.height) return null
    val line = layout.getLineForVertical(y.toInt())
    if (x < layout.getLineLeft(line) || x > layout.getLineRight(line)) return null
    val offset = layout.getOffsetForHorizontal(line, x)
    // The offset sits between characters; the tapped one is at or just before it.
    val spans = text.getSpans(offset, offset, MarkSpan::class.java)
    return spans.lastOrNull { text.getSpanStart(it) <= offset && offset <= text.getSpanEnd(it) }?.markId
  }

  private fun isExceedingSlop(event: MotionEvent): Boolean = abs(event.x - touchDownX) > touchSlop || abs(event.y - touchDownY) > touchSlop
}
