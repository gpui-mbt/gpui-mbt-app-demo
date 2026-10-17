///|
fn test_rect(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @primitives.Rect {
  @primitives.Rect::new(x, y, width, height).unwrap()
}

///|
fn test_measure(
  document : @text.TextDocument,
) -> Result[@text_layout.TextMeasurement, @text_field.TextFieldError] {
  let carets : Array[@text_layout.CaretGeometry] = []
  let mut offset = 0
  let mut x = 0.0
  carets.push(
    @text_layout.CaretGeometry::new(
      0,
      true,
      test_rect(0.0, 0.0, 1.0, 16.0),
      test_rect(0.0, 0.0, 1.0, 16.0),
    ).unwrap(),
  )
  for scalar in document.text().iter() {
    offset += if scalar.to_int() > 0xFFFF { 2 } else { 1 }
    x += if scalar.to_int() > 0xFFFF { 16.0 } else { 8.0 }
    carets.push(
      @text_layout.CaretGeometry::new(
        offset,
        true,
        test_rect(x, 0.0, 1.0, 16.0),
        test_rect(x, 0.0, 1.0, 16.0),
      ).unwrap(),
    )
  }
  let width = if x < 1.0 { 1.0 } else { x + 1.0 }
  let bounds = test_rect(0.0, 0.0, width, 20.0)
  match
    @text_layout.TextMeasurement::new(
      document, bounds, bounds, 12.0, 1, 0, carets,
    ) {
    Ok(value) => Ok(value)
    Err(_) => Err(@text_field.MeasurementFailed)
  }
}

///|
fn test_admit(
  document : @text.TextDocument,
  measurement : @text_layout.TextMeasurement,
) -> Result[Unit, @text_field.TextFieldError] {
  if measurement.document() != document {
    return Err(@text_field.AdmissionFailed)
  }
  match @text_field.scene_text_run_geometry(measurement) {
    Ok(_) => Ok(())
    Err(_) => Err(@text_field.UnsupportedLayout)
  }
}

///|
test "portable scene composes the overview without a native text backend" {
  let state = @model.DemoState::new()
  let layout = @model.layout(state, 1040.0, 720.0)
  let document = @text.TextDocument::new("").unwrap()
  let note_bounds = match layout.note_field {
    Some(value) => value.bounds
    None => abort("overview note field was not laid out")
  }
  let note = @text_field.TextField::new(
    @model.NOTE_FIELD_ID,
    note_bounds,
    16.0,
    document,
    test_measure,
    test_admit,
  ).unwrap()
  let palette_document = @text.TextDocument::new("").unwrap()
  let palette_field = @text_field.TextField::new(
    @model.PALETTE_FIELD_ID,
    layout.palette.field,
    16.0,
    palette_document,
    test_measure,
    test_admit,
  ).unwrap()
  let palette = @command_palette.CommandPalette::new(palette_field, []).unwrap()
  let buttons : Array[@button.Button] = []
  for
    kind in [
      @model.ButtonKind::Increment,
      @model.ButtonKind::Reset,
      @model.ButtonKind::Copy,
      @model.ButtonKind::CycleAccent,
      @model.ButtonKind::ToggleLoading,
      @model.ButtonKind::OpenPalette,
      @model.ButtonKind::OpenPaletteCard,
      @model.ButtonKind::Disabled,
    ] {
    let bounds = match layout.button(kind) {
      Some(value) => value.bounds
      None => test_rect(0.0, 0.0, 100.0, 32.0)
    }
    buttons.push(@button.Button::new(kind.id(), bounds, kind.label()).unwrap())
  }
  let root = @element.ElementNode::new(1UL, None, layout.viewport)
  let note_node = note.element_node(Some(1UL))
  let tree = @element.ElementTree::new([root, note_node])
    .unwrap()
    .with_focus(@model.NOTE_FIELD_ID)
    .unwrap()
  let inputs = @scene.SceneInputs::new(
    state,
    layout,
    buttons,
    note,
    palette,
    tree,
    None,
    None,
    fn(text, size) {
      @scene.SceneTextMetrics::new(
        text.length().to_double() * size * 0.55,
        size * 1.25,
      )
    },
    "test",
  )
  let snapshot = inputs.build_scene(layout.viewport, 1.0).unwrap()
  assert_true(snapshot.items().length() > 20)
  assert_true(snapshot.viewport() == layout.viewport)
  assert_true(snapshot.scale() == 1.0)
  assert_true(
    snapshot
    .items()
    .any(fn(item) {
      match item {
        @gpui_scene.TextRunItem(..) => true
        _ => false
      }
    }),
  )
}
