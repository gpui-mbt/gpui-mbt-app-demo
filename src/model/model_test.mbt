///|
test "demo state applies pure intents and bounds activity" {
  let state = @model.DemoState::new()
  assert_true(state.page == @model.Overview)
  assert_true(state.apply_intent(@model.Increment))
  assert_eq(state.clicks, 1)
  assert_eq(state.activity[0], "Increment -> 1")
  assert_true(state.apply_intent(@model.ToggleLoading))
  assert_true(state.loading)
  assert_true(state.apply_intent(@model.Increment))
  assert_eq(state.clicks, 1)
  assert_true(state.apply_intent(@model.CycleAccent))
  assert_true(state.accent == @model.Violet)
  assert_true(state.apply_intent(@model.Go(@model.Lists)))
  assert_true(state.page == @model.Lists)
  assert_true(state.apply_intent(@model.Reset))
  assert_eq(state.clicks, 0)
  assert_eq(state.activity.length(), 1)
  assert_false(state.loading)
  for index in 0..<40 {
    state.record("row \{index}")
  }
  assert_eq(state.activity.length(), @model.MAX_ACTIVITY)
}

///|
test "demo state keeps copy focus and quit as app-owned intents" {
  let state = @model.DemoState::new()
  assert_false(state.apply_intent(@model.CopySummary))
  assert_false(state.apply_intent(@model.FocusNote))
  assert_false(state.apply_intent(@model.Quit))
  assert_eq(state.clicks, 0)
}

///|
test "demo selection clamps and reveals rows through scroll state" {
  let state = @model.DemoState::new()
  state.sync_list_scroll(@primitives.Size::new(100.0, 100.0).unwrap())
  state.select(@model.Items, 39)
  assert_true(state.list_selected == Some(39))
  assert_true(state.scroll_list.offset().y() > 0.0)
  state.move_selection(@model.Items, 1)
  assert_true(state.list_selected == Some(39))
  state.select(@model.Items, -5)
  assert_true(state.list_selected == Some(0))
  assert_eq(state.scroll_list.offset().y(), 0.0)
  state.select(@model.Activity, 99)
  assert_true(state.activity_selected == Some(state.activity_count() - 1))
  state.clear_selection(@model.Activity)
  assert_true(state.activity_selected is None)
}

///|
test "demo summary includes live state" {
  let state = @model.DemoState::new()
  state.increment()
  state.cycle_accent()
  let summary = state.summary()
  assert_true(summary.contains("clicks=1"))
  assert_true(summary.contains("accent=Violet"))
  assert_true(summary.contains("page=Overview"))
}
