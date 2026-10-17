///|
fn layout_widget_ids(layout : @model.UiLayout) -> Array[UInt64] {
  layout.widgets().map(region => region.id)
}

///|
fn layout_ids_unique(layout : @model.UiLayout) -> Bool {
  let ids = layout_widget_ids(layout)
  for left in 0..<ids.length() {
    for right in (left + 1)..<ids.length() {
      if ids[left] == ids[right] {
        return false
      }
    }
  }
  true
}

///|
test "layout resolves wide overview cards and controls" {
  let state = @model.DemoState::new()
  let layout = @model.layout(state, 1040.0, 720.0)
  assert_eq(layout.sidebar.size().width(), @model.SIDEBAR_WIDE)
  assert_eq(layout.nav.length(), 4)
  assert_eq(layout.cards.length(), 5)
  assert_eq(layout.buttons.length(), 4)
  assert_true(layout.note_field is Some(_))
  assert_true(layout.activity is Some(_))
  assert_true(layout_ids_unique(layout))
  let activity = layout.activity.unwrap()
  assert_true(activity.viewport.left() >= layout.content.left())
  assert_eq(
    activity.content_height,
    @model.ROW_HEIGHT * state.activity_count().to_double(),
  )
  let field = layout.note_field.unwrap()
  assert_true(field.bounds.left() >= layout.content.left())
  assert_true(field.bounds.right() <= layout.content.right())
}

///|
test "layout switches to a rail and one-column cards when narrow" {
  let state = @model.DemoState::new()
  let layout = @model.layout(state, 820.0, 640.0)
  assert_eq(layout.sidebar.size().width(), @model.SIDEBAR_RAIL)
  assert_eq(layout.cards.length(), 5)
  let buttons = layout.buttons
  assert_true(buttons.length() >= 4)
  for button in buttons {
    assert_true(button.bounds.left() >= layout.content.left() - 0.1)
    assert_true(button.bounds.right() <= layout.content.right() + 0.1)
  }
}

///|
test "layout covers controls lists and about pages" {
  let state = @model.DemoState::new()
  state.go(@model.Controls)
  let controls = @model.layout(state, 1040.0, 720.0)
  assert_true(controls.page == @model.Controls)
  assert_eq(controls.cards.length(), 4)
  assert_true(controls.note_field is Some(_))
  assert_eq(controls.swatches.length(), 3)
  assert_true(controls.button(@model.Increment) is Some(_))
  assert_true(controls.button(@model.OpenPalette) is Some(_))

  state.go(@model.Lists)
  let lists = @model.layout(state, 1040.0, 720.0)
  assert_eq(lists.cards.length(), 1)
  assert_true(lists.list is Some(_))
  assert_true(lists.note_field is None)
  assert_eq(
    lists.list.unwrap().content_height,
    @model.ROW_HEIGHT * @model.LIST_ROWS.to_double(),
  )

  state.go(@model.About)
  let about = @model.layout(state, 1040.0, 720.0)
  assert_eq(about.cards.length(), 2)
  assert_eq(about.buttons.length(), 0)
}

///|
test "palette layout stays inside small and large viewports" {
  let state = @model.DemoState::new()
  for (width, height) in [(800.0, 600.0), (1400.0, 900.0)] {
    let layout = @model.layout(state, width, height)
    let palette = layout.palette
    assert_true(palette.panel.left() >= 0.0)
    assert_true(palette.panel.top() >= 0.0)
    assert_true(palette.panel.right() <= width + 0.1)
    assert_true(palette.panel.bottom() <= height + 0.1)
    assert_true(palette.field.right() <= palette.panel.right())
    assert_true(palette.rows.length() <= 8)
    if palette.rows.length() > 0 {
      assert_true(palette.rows[0].bottom() <= palette.list.bottom() + 0.1)
    }
  }
}
