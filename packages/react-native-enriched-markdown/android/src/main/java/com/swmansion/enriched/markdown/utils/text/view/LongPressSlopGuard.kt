package com.swmansion.enriched.markdown.utils.text.view

import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import kotlin.math.abs

/**
 * View's long press survives any movement that stays inside the view; a parent
 * ScrollView only cancels it once it intercepts. A slow drag still under the
 * intercept threshold when the timeout fires starts a text selection, and the
 * Editor then keeps the gesture, so the drag extends the selection instead of
 * scrolling. Require the finger to hold still for a long press, as iOS does.
 */
class LongPressSlopGuard(
  private val view: View,
) {
  private val touchSlop = ViewConfiguration.get(view.context).scaledTouchSlop
  private val longPressTimeout = ViewConfiguration.getLongPressTimeout()
  private var downX = 0f
  private var downY = 0f
  private var tracking = false

  fun onTouchEvent(event: MotionEvent) {
    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        downX = event.x
        downY = event.y
        tracking = true
      }

      MotionEvent.ACTION_MOVE -> {
        if (!tracking) return
        // Past the timeout the long press already fired (or a selection drag is
        // live); cancelling then would make the Editor drop the ACTION_UP.
        if (event.eventTime - event.downTime >= longPressTimeout) {
          tracking = false
        } else if (abs(event.x - downX) > touchSlop || abs(event.y - downY) > touchSlop) {
          tracking = false
          view.cancelLongPress()
        }
      }

      MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> tracking = false
    }
  }
}
