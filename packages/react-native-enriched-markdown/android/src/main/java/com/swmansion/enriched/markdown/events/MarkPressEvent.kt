package com.swmansion.enriched.markdown.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event

class MarkPressEvent(
  surfaceId: Int,
  viewId: Int,
  private val markId: String,
) : Event<MarkPressEvent>(surfaceId, viewId) {
  override fun getEventName(): String = EVENT_NAME

  override fun getEventData(): WritableMap {
    val eventData: WritableMap = Arguments.createMap()
    eventData.putString("id", markId)
    return eventData
  }

  companion object {
    const val EVENT_NAME: String = "onMarkPress"
  }
}
