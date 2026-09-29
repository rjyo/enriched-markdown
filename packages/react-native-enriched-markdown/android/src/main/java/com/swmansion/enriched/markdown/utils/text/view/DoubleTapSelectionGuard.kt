package com.swmansion.enriched.markdown.utils.text.view

import android.view.MotionEvent
import android.view.ViewConfiguration

/**
 * A selectable TextView selects the word under a double tap, so quick taps
 * while scrolling (stopping a fling, then tapping again) start selections.
 * Keep selection on long press only, as on iOS.
 *
 * Android 11+ counts a double tap only when the previous tap's down→up took at
 * most the double-tap timeout (EditorTouchState), and nothing else in the
 * Editor reads that ACTION_UP time. Handing the Editor each quick tap's UP
 * stamped just past the timeout makes the next tap a first tap again. Android
 * 9–10 time taps with SystemClock and keep the stock behavior.
 */
object DoubleTapSelectionGuard {
  private val doubleTapTimeout = ViewConfiguration.getDoubleTapTimeout()

  /** The event to pass to TextView.onTouchEvent; recycle it if it isn't [event]. */
  fun eventForEditor(event: MotionEvent): MotionEvent {
    if (event.actionMasked != MotionEvent.ACTION_UP) return event
    val heldUntil = event.downTime + doubleTapTimeout + 1
    if (event.eventTime >= heldUntil) return event

    val pointerCount = event.pointerCount
    val properties = Array(pointerCount) { MotionEvent.PointerProperties().also { p -> event.getPointerProperties(it, p) } }
    val coords = Array(pointerCount) { MotionEvent.PointerCoords().also { c -> event.getPointerCoords(it, c) } }
    return MotionEvent.obtain(
      event.downTime,
      heldUntil,
      event.action,
      pointerCount,
      properties,
      coords,
      event.metaState,
      event.buttonState,
      event.xPrecision,
      event.yPrecision,
      event.deviceId,
      event.edgeFlags,
      event.source,
      event.flags,
    )
  }
}
