package com.swmansion.enriched.markdown.utils.text.view

import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewTreeObserver
import android.widget.OverScroller
import android.widget.ScrollView
import java.lang.reflect.Field
import kotlin.math.abs

/**
 * Keeps touches that belong to the list's scrolling from starting a selection.
 *
 * A touch during a fling is the ScrollView's (it intercepts and stops the
 * fling), but a fling's last stretch barely moves, so a touch meant to stop a
 * list that still looks like it's moving often lands just after the scroller
 * finished; and an animated scrollTo runs outside the scroller, so the
 * ScrollView never intercepts at all. Those touches reach the text, and a
 * finger resting on it for the long-press timeout started a selection. No long
 * press for a touch that starts within [SETTLE_MS] of a fling, or once the text
 * moves under the finger — as on iOS, where a scrolling list owns the touch.
 */
class ScrollTouchGuard(
  private val view: View,
) : ViewTreeObserver.OnScrollChangedListener {
  private val touchSlop = ViewConfiguration.get(view.context).scaledTouchSlop
  private val longPressTimeout = ViewConfiguration.getLongPressTimeout()
  private val location = IntArray(2)
  private var downX = 0
  private var downY = 0
  private var downTime = 0L
  private var watcher: FlingWatcher? = null
  private var observer: ViewTreeObserver? = null

  fun onAttachedToWindow() {
    watcher = FlingWatcher.around(view)
  }

  fun onDetachedFromWindow() {
    stopWatchingPosition()
    watcher = null
  }

  /** Call after the TextView handled [event], so its long press is already scheduled. */
  fun onTouchEvent(event: MotionEvent) {
    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        stopWatchingPosition()
        val sinceFling = watcher?.millisSinceFling(event.eventTime)
        if (sinceFling != null && sinceFling < SETTLE_MS) {
          view.cancelLongPress()
          return
        }
        view.getLocationOnScreen(location)
        downX = location[0]
        downY = location[1]
        downTime = event.eventTime
        observer = view.viewTreeObserver.also { it.addOnScrollChangedListener(this) }
      }

      MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> stopWatchingPosition()
    }
  }

  override fun onScrollChanged() {
    // Past the timeout the long press already fired; its drag owns the touch.
    if (SystemClock.uptimeMillis() - downTime >= longPressTimeout) {
      stopWatchingPosition()
      return
    }
    view.getLocationOnScreen(location)
    if (abs(location[0] - downX) > touchSlop || abs(location[1] - downY) > touchSlop) {
      view.cancelLongPress()
      stopWatchingPosition()
    }
  }

  private fun stopWatchingPosition() {
    observer?.takeIf { it.isAlive }?.removeOnScrollChangedListener(this)
    observer = null
  }

  private companion object {
    const val SETTLE_MS = 300L
  }
}

/**
 * Remembers when a ScrollView's fling last moved it; one per attached
 * ScrollView, dropped when it detaches so neither outlives the other.
 */
private class FlingWatcher(
  private val scrollView: ScrollView,
  private val scroller: OverScroller,
) : ViewTreeObserver.OnScrollChangedListener,
  View.OnAttachStateChangeListener {
  private var observer: ViewTreeObserver? = null
  private var lastFlingAt = Long.MIN_VALUE

  override fun onScrollChanged() {
    if (!scroller.isFinished) lastFlingAt = SystemClock.uptimeMillis()
  }

  fun millisSinceFling(now: Long): Long? = if (lastFlingAt == Long.MIN_VALUE) null else now - lastFlingAt

  override fun onViewAttachedToWindow(v: View) = Unit

  override fun onViewDetachedFromWindow(v: View) {
    observer?.takeIf { it.isAlive }?.removeOnScrollChangedListener(this)
    observer = null
    scrollView.removeOnAttachStateChangeListener(this)
    watchers.remove(scrollView)
  }

  companion object {
    private val watchers = HashMap<ScrollView, FlingWatcher>()

    // ScrollView keeps its fling in a private OverScroller; React Native's
    // ReactScrollView reads the same field. Without it, only the moved-under-
    // the-finger check runs.
    private val scrollerField: Field? by lazy {
      runCatching { ScrollView::class.java.getDeclaredField("mScroller").apply { isAccessible = true } }.getOrNull()
    }

    fun around(view: View): FlingWatcher? {
      var parent = view.parent
      while (parent != null && parent !is ScrollView) parent = parent.parent
      val scrollView = (parent as? ScrollView)?.takeIf { it.isAttachedToWindow } ?: return null
      watchers[scrollView]?.let { return it }
      val scroller = scrollerField?.get(scrollView) as? OverScroller ?: return null
      return FlingWatcher(scrollView, scroller).also {
        it.observer = scrollView.viewTreeObserver.apply { addOnScrollChangedListener(it) }
        scrollView.addOnAttachStateChangeListener(it)
        watchers[scrollView] = it
      }
    }
  }
}
