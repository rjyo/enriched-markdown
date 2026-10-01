package com.swmansion.enriched.markdown

import android.content.Context
import android.graphics.Canvas
import android.os.Build
import android.text.Layout
import android.text.Spannable
import android.util.AttributeSet
import android.view.MotionEvent
import com.swmansion.enriched.markdown.accessibility.AccessibilityLabels
import com.swmansion.enriched.markdown.accessibility.AccessibleMarkdownTextView
import com.swmansion.enriched.markdown.spans.MarkSpan
import com.swmansion.enriched.markdown.spans.MarkedRange
import com.swmansion.enriched.markdown.spoiler.SpoilerCapable
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlay
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayDrawer
import com.swmansion.enriched.markdown.utils.text.interaction.CheckboxTouchHelper
import com.swmansion.enriched.markdown.utils.text.interaction.MarkTouchHelper
import com.swmansion.enriched.markdown.utils.text.view.LinkLongPressMovementMethod
import com.swmansion.enriched.markdown.utils.text.view.DoubleTapSelectionGuard
import com.swmansion.enriched.markdown.utils.text.view.LongPressSlopGuard
import com.swmansion.enriched.markdown.utils.text.view.ScrollTouchGuard
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig
import com.swmansion.enriched.markdown.utils.text.view.applySelectableState
import com.swmansion.enriched.markdown.utils.text.view.cancelJSTouchForCheckboxTap
import com.swmansion.enriched.markdown.utils.text.view.cancelJSTouchForLinkTap
import com.swmansion.enriched.markdown.utils.text.view.createSelectionActionModeCallback
import com.swmansion.enriched.markdown.utils.text.view.reallowParentInterceptIfLinkReleased
import com.swmansion.enriched.markdown.utils.text.view.setupAsMarkdownTextView
import com.swmansion.enriched.markdown.views.BlockSegmentView

class EnrichedMarkdownInternalText
  @JvmOverloads
  constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
  ) : AccessibleMarkdownTextView(context, attrs, defStyleAttr),
    BlockSegmentView,
    SpoilerCapable {
    var lastElementMarginBottom: Float = 0f

    private val checkboxTouchHelper = CheckboxTouchHelper(this)
    private val longPressSlopGuard = LongPressSlopGuard(this)
    private val scrollTouchGuard = ScrollTouchGuard(this)
    private val markTouchHelper = MarkTouchHelper(this)

    /** Fired with a marked range's id when it's tapped. */
    var onMarkPressCallback: ((markId: String) -> Unit)?
      get() = markTouchHelper.onMarkTap
      set(value) {
        markTouchHelper.onMarkTap = value
      }

    var onTaskListItemPressCallback: ((taskIndex: Int, checked: Boolean, itemText: String) -> Unit)?
      get() = checkboxTouchHelper.onCheckboxTap
      set(value) {
        checkboxTouchHelper.onCheckboxTap = value
      }

    var enableTaskListItemToggle: Boolean
      get() = checkboxTouchHelper.isEnabled
      set(value) {
        checkboxTouchHelper.isEnabled = value
      }

    override val segmentMarginBottom: Int get() = lastElementMarginBottom.toInt()

    override var spoilerOverlayDrawer: SpoilerOverlayDrawer? = null
      private set
    var spoilerOverlay: SpoilerOverlay = SpoilerOverlay.PARTICLES
    private var contextMenuItemTexts: List<String> = emptyList()
    private var onContextMenuItemPress: ((itemText: String, selectedText: String, selectionStart: Int, selectionEnd: Int) -> Unit)? = null
    var selectionMenuConfig: SelectionMenuConfig = SelectionMenuConfig()
    var accessibilityLabels: AccessibilityLabels = AccessibilityLabels()
      set(value) {
        field = value
        accessibilityHelper.labels = value
      }

    init {
      setupAsMarkdownTextView()
      customSelectionActionModeCallback =
        createSelectionActionModeCallback(
          this,
          getCustomItemTexts = { contextMenuItemTexts },
          getSelectionMenuConfig = { selectionMenuConfig },
          onCustomItemPress = { itemText, selectedText, start, end ->
            onContextMenuItemPress?.invoke(itemText, selectedText, start, end)
          },
        )
    }

    fun applyStyledText(styledText: CharSequence) {
      text = styledText

      if (movementMethod !is LinkLongPressMovementMethod) {
        movementMethod = LinkLongPressMovementMethod.createInstance()
      }

      spoilerOverlayDrawer = SpoilerOverlayDrawer.setupIfNeeded(this, styledText, spoilerOverlayDrawer, spoilerOverlay)
      accessibilityHelper.invalidateAccessibilityItems()
    }

    override fun onDraw(canvas: Canvas) {
      super.onDraw(canvas)
      spoilerOverlayDrawer?.draw(canvas)
    }

    override fun onDetachedFromWindow() {
      scrollTouchGuard.onDetachedFromWindow()
      spoilerOverlayDrawer?.stop()
      spoilerOverlayDrawer = null
      super.onDetachedFromWindow()
    }

    /** Repaints the marks inside this segment, whose first character sits at `base`. */
    fun applyMarkedRanges(
      marks: List<MarkedRange>,
      base: Int,
      color: Int?,
    ) {
      val spannable = text as? Spannable ?: return
      MarkSpan.apply(spannable, marks, base, color)
    }

    fun setIsSelectable(selectable: Boolean) {
      applySelectableState(selectable)
    }

    fun setContextMenuItems(
      items: List<String>,
      onPress: (itemText: String, selectedText: String, selectionStart: Int, selectionEnd: Int) -> Unit,
    ) {
      contextMenuItemTexts = items
      onContextMenuItemPress = onPress
    }

    /**
     * The Editor enables its selection controller only when the text has a
     * layout and the view's root is a window, and re-checks that only on
     * setText/setMovementMethod. Segments are laid out while their subtree is
     * still detached (always the case inside FlatList cells), so the controller
     * stays disabled and long-press logs "TextView does not support text
     * selection". Re-setting the movement method re-runs that check once
     * attached. Skipped while a selection is live: it would drop the handles.
     */
    private fun refreshSelectionControllers() {
      if (!isTextSelectable || !isAttachedToWindow || layout == null || hasSelection()) return
      val movement = movementMethod
      movementMethod = null
      movementMethod = movement
    }

    override fun onAttachedToWindow() {
      super.onAttachedToWindow()
      scrollTouchGuard.onAttachedToWindow()
      refreshSelectionControllers()
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
      super.onLayout(changed, left, top, right, bottom)
      if (changed) refreshSelectionControllers()
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
      if (checkboxTouchHelper.onTouchEvent(event)) {
        if (event.action == MotionEvent.ACTION_DOWN) {
          cancelJSTouchForCheckboxTap(event)
        }
        return true
      }
      // A tap on a mark reports the mark instead of reaching links or RN
      // touch handlers; the text view is told the gesture was cancelled.
      if (markTouchHelper.onTouchEvent(event) != null) {
        val cancel = MotionEvent.obtain(event).apply { action = MotionEvent.ACTION_CANCEL }
        super.onTouchEvent(cancel)
        cancel.recycle()
        parent?.requestDisallowInterceptTouchEvent(false)
        return true
      }
      if (event.action == MotionEvent.ACTION_DOWN && markTouchHelper.isTracking) {
        cancelJSTouchForCheckboxTap(event)
      }
      val editorEvent = DoubleTapSelectionGuard.eventForEditor(event)
      val result = super.onTouchEvent(editorEvent)
      if (editorEvent !== event) editorEvent.recycle()
      longPressSlopGuard.onTouchEvent(event)
      scrollTouchGuard.onTouchEvent(event)
      when (event.action) {
        MotionEvent.ACTION_DOWN -> cancelJSTouchForLinkTap(event)
        else -> reallowParentInterceptIfLinkReleased()
      }
      return result
    }

    fun setJustificationMode(needsJustify: Boolean) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        justificationMode =
          if (needsJustify) {
            Layout.JUSTIFICATION_MODE_INTER_WORD
          } else {
            Layout.JUSTIFICATION_MODE_NONE
          }
      }
    }
  }
