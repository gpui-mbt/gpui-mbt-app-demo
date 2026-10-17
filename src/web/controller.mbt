///|
const WEB_ROOT_ID : UInt64 = 1UL

///|
type WebTextField = @text_field.TextField

///|
type WebPalette = @command_palette.CommandPalette

///|
type WebDocument = @text.TextDocument

///|
type WebTextMeasurement = @text_layout.TextMeasurement

///|
type WebTextFieldError = @text_field.TextFieldError

///|
fn web_error(
  operation : String,
  message : String,
) -> @diagnostics.FrameworkError {
  @diagnostics.FrameworkError::new(
    @diagnostics.InvalidInput,
    operation,
    subsystem="gpui-mbt-app-demo-web",
    backend="browser-canvas",
    message~,
  )
}

///|
fn web_rect(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @primitives.Rect {
  @primitives.Rect::new(x, y, width, height).unwrap()
}

///|
fn web_caret(x : Double) -> @primitives.Rect {
  web_rect(x, 0.0, 1.0, 16.0)
}

///|
fn web_measure_text(
  document : WebDocument,
) -> Result[WebTextMeasurement, WebTextFieldError] {
  let carets : Array[@text_layout.CaretGeometry] = []
  carets.push(
    @text_layout.CaretGeometry::new(0, true, web_caret(0.0), web_caret(0.0)).unwrap(),
  )
  let mut offset = 0
  let mut x = 0.0
  for scalar in document.text().iter() {
    if scalar.to_int() > 0xFFFF {
      offset += 2
      x += 16.0
    } else {
      offset += 1
      x += 8.0
    }
    carets.push(
      @text_layout.CaretGeometry::new(offset, true, web_caret(x), web_caret(x)).unwrap(),
    )
  }
  let width = if x < 1.0 { 1.0 } else { x + 1.0 }
  let bounds = web_rect(0.0, 0.0, width, 20.0)
  match
    @text_layout.TextMeasurement::new(
      document, bounds, bounds, 12.0, 1, 0, carets,
    ) {
    Ok(value) => Ok(value)
    Err(_) => Err(@text_field.MeasurementFailed)
  }
}

///|
fn web_admit(
  document : WebDocument,
  measurement : WebTextMeasurement,
) -> Result[Unit, WebTextFieldError] {
  if measurement.document() != document {
    return Err(@text_field.AdmissionFailed)
  }
  match @text_field.scene_text_run_geometry(measurement) {
    Err(_) => Err(@text_field.UnsupportedLayout)
    Ok(_) => Ok(())
  }
}

///|
fn web_hit(
  document : WebDocument,
  point : @primitives.Point,
) -> Result[@text_layout.TextHit, WebTextFieldError] {
  let measurement = match web_measure_text(document) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let carets = measurement.carets()
  if carets.length() == 0 {
    return Err(@text_field.HitTestFailed)
  }
  let mut nearest = carets[0].utf16_offset()
  let mut distance = (carets[0].strong().left() - point.x()).abs()
  for caret in carets {
    let dx = (caret.strong().left() - point.x()).abs()
    if dx < distance {
      nearest = caret.utf16_offset()
      distance = dx
    }
  }
  match @text_layout.TextHit::new(document, nearest, 0, nearest, true, true) {
    Ok(value) => Ok(value)
    Err(_) => Err(@text_field.HitTestFailed)
  }
}

///|
fn web_command_binding(
  id : String,
  label : String,
  intents : Ref[Array[String]],
) -> @capability.GuiBinding[Unit, Unit] {
  let descriptor = @capability.Descriptor::new(
    id,
    label,
    "gpui-mbt-app-demo web",
    @capability.Command,
    @capability.Schema::unit(),
    @capability.Schema::unit(),
    @capability.StateChange,
    false,
    @capability.Local,
    None,
    1,
  ).unwrap()
  @capability.TypedCapability::new(
    descriptor,
    _ => Ok(()),
    _ => Ok(@capability.Value::unit()),
    _ => {
      intents.val.push(id)
      Ok(())
    },
    () => Ok(()),
    _ => Ok(()),
  ).gui_binding()
}

///|
fn web_commands(
  intents : Ref[Array[String]],
) -> Array[@command_palette.PaletteCommand] {
  let values = [
    ("demo.go_overview", "go to overview"),
    ("demo.go_controls", "go to controls"),
    ("demo.go_lists", "go to lists"),
    ("demo.go_about", "go to about"),
    ("demo.increment", "increment counter"),
    ("demo.reset", "reset demo"),
    ("demo.copy", "copy summary"),
    ("demo.toggle_loading", "toggle loading"),
    ("demo.cycle_accent", "cycle accent"),
    ("demo.focus_note", "focus note field"),
    ("demo.quit", "quit demo"),
  ]
  let commands : Array[@command_palette.PaletteCommand] = []
  for (id, label) in values {
    let metadata = @command_palette.CommandMetadata::new(id, label, true).unwrap()
    commands.push(
      @command_palette.PaletteCommand::new(
        metadata,
        web_command_binding(id, label, intents),
      ),
    )
  }
  commands
}

///|
fn web_empty_document() -> Result[WebDocument, @diagnostics.FrameworkError] {
  match @text.TextDocument::new("") {
    Ok(value) => Ok(value)
    Err(_) => Err(web_error("text_document", "empty document was rejected"))
  }
}

///|
fn web_note_field(
  bounds : @primitives.Rect,
) -> Result[WebTextField, @diagnostics.FrameworkError] {
  let document = match web_empty_document() {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  match
    @text_field.TextField::new(
      @model.NOTE_FIELD_ID,
      bounds,
      16.0,
      document,
      web_measure_text,
      web_admit,
    ) {
    Ok(value) => Ok(value)
    Err(_) =>
      Err(web_error("note_field", "TextField rejected the web note field"))
  }
}

///|
fn web_palette(
  bounds : @primitives.Rect,
  intents : Ref[Array[String]],
) -> Result[WebPalette, @diagnostics.FrameworkError] {
  let document = match web_empty_document() {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let field = match
    @text_field.TextField::new(
      @model.PALETTE_FIELD_ID,
      bounds,
      16.0,
      document,
      web_measure_text,
      web_admit,
    ) {
    Ok(value) => value
    Err(_) =>
      return Err(
        web_error("palette_field", "TextField rejected the web palette field"),
      )
  }
  match @command_palette.CommandPalette::new(field, web_commands(intents)) {
    Ok(value) => Ok(value)
    Err(_) => Err(web_error("palette", "CommandPalette rejected web commands"))
  }
}

///|
fn web_button_kinds() -> Array[@model.ButtonKind] {
  [
    @model.Increment,
    @model.Reset,
    @model.Copy,
    @model.CycleAccent,
    @model.ToggleLoading,
    @model.OpenPalette,
    @model.OpenPaletteCard,
    @model.Disabled,
  ]
}

///|
fn web_button_id(id : UInt64) -> @model.ButtonKind? {
  @model.ButtonKind::from_id(id)
}

///|
priv struct WebController {
  mut width : Double
  mut height : Double
  mut scale : Double
  state : @model.DemoState
  mut layout : @model.UiLayout
  buttons : Array[@button.Button]
  mut note : WebTextField
  mut palette : WebPalette
  mut palette_field_rect : @primitives.Rect
  mut tree : @element.ElementTree
  intents : Ref[Array[String]]
  mut hovered : UInt64?
  mut pointer : @primitives.Point?
}

///|
fn web_placeholder_tree(
  width : Double,
  height : Double,
) -> @element.ElementTree {
  match
    @element.ElementTree::new([
      @element.ElementNode::new(
        WEB_ROOT_ID,
        None,
        web_rect(0.0, 0.0, width, height),
      ),
    ]) {
    Ok(value) => value
    Err(_) => abort("web root element was rejected")
  }
}

///|
fn web_placeholder_rect() -> @primitives.Rect {
  web_rect(0.0, 0.0, 100.0, 40.0)
}

///|
fn WebController::new(
  width : Double,
  height : Double,
  scale : Double,
) -> Result[WebController, @diagnostics.FrameworkError] {
  let state = @model.DemoState::new()
  let layout = @model.layout(state, width, height)
  let note_bounds = match layout.note_field {
    Some(value) => value.bounds
    None => web_placeholder_rect()
  }
  let note = match web_note_field(note_bounds) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let intents : Ref[Array[String]] = Ref([])
  let palette = match web_palette(layout.palette.field, intents) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let buttons : Array[@button.Button] = []
  for kind in web_button_kinds() {
    let button = match
      @button.Button::new(kind.id(), web_placeholder_rect(), kind.label()) {
      Ok(value) => value
      Err(_) => return Err(web_error("button", "Button rejected a web action"))
    }
    if kind == @model.Disabled {
      buttons.push(button.with_enabled(false))
    } else {
      buttons.push(button)
    }
  }
  let controller = {
    width,
    height,
    scale,
    state,
    layout,
    buttons,
    note,
    palette,
    palette_field_rect: layout.palette.field,
    tree: web_placeholder_tree(width, height),
    intents,
    hovered: None,
    pointer: None,
  }
  match controller.refresh_layout() {
    Err(error) => Err(error)
    Ok(_) => Ok(controller)
  }
}

///|
fn WebController::button(
  self : WebController,
  kind : @model.ButtonKind,
) -> @button.Button? {
  for button in self.buttons {
    if button.id() == kind.id() {
      return Some(button)
    }
  }
  None
}

///|
fn WebController::replace_button(
  self : WebController,
  button : @button.Button,
) -> Unit {
  let id = button.id()
  for index in 0..<self.buttons.length() {
    if self.buttons[index].id() == id {
      self.buttons[index] = button
      return
    }
  }
}

///|
fn WebController::rebuild_palette(
  self : WebController,
) -> Result[Unit, @diagnostics.FrameworkError] {
  let palette = match web_palette(self.layout.palette.field, self.intents) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  self.palette = palette
  self.palette_field_rect = self.layout.palette.field
  Ok(())
}

///|
fn WebController::sync_controls(self : WebController) -> Unit {
  let focused = self.tree.focused()
  for kind in web_button_kinds() {
    let button = match self.button(kind) {
      None => continue
      Some(value) => value
    }
    let mut next = button.with_focus(focused == Some(kind.id()))
    if kind == @model.Increment {
      next = next.with_loading(self.state.loading)
    }
    if kind == @model.Disabled {
      next = next.with_enabled(false)
    }
    self.replace_button(next)
  }
  let note_focused = focused == Some(@model.NOTE_FIELD_ID) &&
    !self.palette.is_open()
  match self.note.with_focus(note_focused) {
    Err(_) => ()
    Ok(value) => self.note = value
  }
}

///|
fn WebController::make_tree(
  self : WebController,
  include_palette : Bool,
) -> Result[@element.ElementTree, @diagnostics.FrameworkError] {
  let nodes : Array[@element.ElementNode] = []
  nodes.push(@element.ElementNode::new(WEB_ROOT_ID, None, self.layout.viewport))
  for region in self.layout.nav {
    nodes.push(
      @element.ElementNode::new(region.id, Some(WEB_ROOT_ID), region.bounds).with_focusable(
        true,
      ),
    )
  }
  let palette_button = match self.button(@model.OpenPalette) {
    Some(value) => value
    None => return Err(web_error("tree", "missing palette button"))
  }
  nodes.push(palette_button.element_node(Some(WEB_ROOT_ID)))
  for region in self.layout.buttons {
    match web_button_id(region.id) {
      Some(kind) =>
        match self.button(kind) {
          Some(button) => nodes.push(button.element_node(Some(WEB_ROOT_ID)))
          None => ()
        }
      None => ()
    }
  }
  match self.layout.note_field {
    Some(_) => nodes.push(self.note.element_node(Some(WEB_ROOT_ID)))
    None => ()
  }
  match self.layout.activity {
    Some(region) =>
      nodes.push(
        @element.ElementNode::new(401UL, Some(WEB_ROOT_ID), region.viewport).with_focusable(
          true,
        ),
      )
    None => ()
  }
  match self.layout.list {
    Some(region) =>
      nodes.push(
        @element.ElementNode::new(402UL, Some(WEB_ROOT_ID), region.viewport).with_focusable(
          true,
        ),
      )
    None => ()
  }
  if include_palette {
    nodes.push(
      @element.ElementNode::new(
        9000UL,
        Some(WEB_ROOT_ID),
        self.layout.palette.overlay,
      ),
    )
    nodes.push(
      @element.ElementNode::new(
        9001UL,
        Some(WEB_ROOT_ID),
        self.layout.palette.panel,
      ),
    )
    nodes.push(
      @element.ElementNode::new(
        @model.PALETTE_FIELD_ID,
        Some(WEB_ROOT_ID),
        self.layout.palette.field,
      ).with_focusable(true),
    )
  }
  let tree = match @element.ElementTree::new(nodes) {
    Ok(value) => value
    Err(_) =>
      return Err(web_error("tree", "element tree rejected the web layout"))
  }
  let current = self.tree.focused()
  let fallback = if include_palette {
    @model.PALETTE_FIELD_ID
  } else if self.layout.note_field is Some(_) {
    @model.NOTE_FIELD_ID
  } else {
    100UL + self.state.page.index().to_uint64()
  }
  let target = match current {
    Some(value) => value
    None => fallback
  }
  match tree.with_focus(target) {
    Ok(value) => Ok(value)
    Err(_) =>
      match tree.with_focus(fallback) {
        Ok(value) => Ok(value)
        Err(_) => Ok(tree)
      }
  }
}

///|
fn WebController::refresh_layout(
  self : WebController,
) -> Result[Unit, @diagnostics.FrameworkError] {
  let layout = @model.layout(self.state, self.width, self.height)
  self.layout = layout
  match layout.activity {
    Some(region) => self.state.sync_activity_scroll(region.viewport.size())
    None => ()
  }
  match layout.list {
    Some(region) => self.state.sync_list_scroll(region.viewport.size())
    None => ()
  }
  for kind in web_button_kinds() {
    match layout.button(kind) {
      Some(region) =>
        match self.button(kind) {
          Some(button) =>
            match button.with_bounds(region.bounds) {
              Err(_) => ()
              Ok(value) => self.replace_button(value)
            }
          None => ()
        }
      None => ()
    }
  }
  match layout.note_field {
    Some(region) =>
      match self.note.with_bounds(region.bounds) {
        Err(_) => ()
        Ok(value) => self.note = value
      }
    None => ()
  }
  if !self.palette.is_open() && self.palette_field_rect != layout.palette.field {
    match self.rebuild_palette() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
  }
  let tree = self.make_tree(self.palette.is_open())
  match tree {
    Err(error) => Err(error)
    Ok(value) => {
      self.tree = value
      self.sync_controls()
      Ok(())
    }
  }
}

///|
fn WebController::open_palette(
  self : WebController,
) -> Result[Unit, @diagnostics.FrameworkError] {
  if self.palette.is_open() {
    return Ok(())
  }
  match self.note.with_focus(false) {
    Err(_) => ()
    Ok(value) => self.note = value
  }
  let tree = match self.make_tree(true) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  self.tree = tree
  let tree_ref = Ref(self.tree)
  match self.palette.open(tree_ref) {
    Err(_) => {
      self.tree = tree_ref.val
      match self.refresh_layout() {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      Err(web_error("palette_open", "CommandPalette refused to open"))
    }
    Ok(_) => {
      self.tree = tree_ref.val
      self.sync_controls()
      Ok(())
    }
  }
}

///|
fn WebController::finish_palette_close(
  self : WebController,
  epoch : Int32,
) -> Result[Unit, @diagnostics.FrameworkError] {
  let tree_ref = Ref(self.tree)
  match self.palette.finish_close(epoch, tree_ref) {
    Err(_) => return Err(web_error("palette_close", "palette could not close"))
    Ok(_) => ()
  }
  self.tree = tree_ref.val
  self.palette.retire_key_guard(epoch)
  let pending = self.intents.val
  self.intents.val = []
  for id in pending {
    self.state.palette_actions += 1
    match id {
      "demo.go_overview" => self.state.go(@model.Overview)
      "demo.go_controls" => self.state.go(@model.Controls)
      "demo.go_lists" => self.state.go(@model.Lists)
      "demo.go_about" => self.state.go(@model.About)
      "demo.increment" => ignore(self.state.apply_intent(@model.Increment))
      "demo.reset" => ignore(self.state.apply_intent(@model.Reset))
      "demo.toggle_loading" =>
        ignore(self.state.apply_intent(@model.ToggleLoading))
      "demo.cycle_accent" => ignore(self.state.apply_intent(@model.CycleAccent))
      "demo.focus_note" =>
        self.state.status = "Press Tab or click the note field"
      _ => ()
    }
  }
  match self.refresh_layout() {
    Err(error) => Err(error)
    Ok(_) => Ok(())
  }
}

///|
fn WebController::close_palette(
  self : WebController,
) -> Result[Unit, @diagnostics.FrameworkError] {
  if !self.palette.is_open() {
    return Ok(())
  }
  match self.palette.blur() {
    Err(_) => Err(web_error("palette_close", "palette blur was rejected"))
    Ok(effect) =>
      match effect {
        @command_palette.Closed(epoch~, command_id=_) =>
          self.finish_palette_close(epoch)
        _ => Ok(())
      }
  }
}

///|
fn WebController::scene_json(self : WebController) -> String {
  let measure = fn(text : String, size : Double) {
    @demo_scene.SceneTextMetrics::new(
      text.length().to_double() * size * 0.55,
      size * 1.25,
    )
  }
  let inputs = @demo_scene.SceneInputs::new(
    self.state,
    self.layout,
    self.buttons,
    self.note,
    self.palette,
    self.tree,
    self.hovered,
    self.pointer,
    measure,
    "Canvas 2D",
  )
  match inputs.build_scene(self.layout.viewport, self.scale) {
    Err(_) => "{\"ok\":false,\"error\":\"scene_build_failed\"}"
    Ok(value) => value.canonical_json()
  }
}

///|
let web_runtime : Ref[WebController?] = Ref(None)

///|
#export_name("gpui_app_demo_start")
pub fn web_start() -> String {
  match web_runtime.val {
    Some(_) => "ok"
    None =>
      match WebController::new(1040.0, 720.0, 1.0) {
        Err(error) => "error:" + error.operation()
        Ok(value) => {
          web_runtime.val = Some(value)
          "ok"
        }
      }
  }
}

///|
#export_name("gpui_app_demo_set_viewport")
pub fn web_set_viewport(
  width : Double,
  height : Double,
  scale : Double,
) -> String {
  let controller = match web_runtime.val {
    None => return "error:not_started"
    Some(value) => value
  }
  if width <= 0.0 || height <= 0.0 || scale <= 0.0 {
    return "error:invalid_viewport"
  }
  if controller.palette.is_open() {
    match controller.close_palette() {
      Err(_) => return "error:palette_close"
      Ok(_) => ()
    }
  }
  controller.width = width
  controller.height = height
  controller.scale = scale
  match controller.refresh_layout() {
    Err(error) => "error:" + error.operation()
    Ok(_) => "ok"
  }
}

///|
#export_name("gpui_app_demo_scene")
pub fn web_scene() -> String {
  match web_runtime.val {
    None => "{\"ok\":false,\"error\":\"not_started\"}"
    Some(controller) => controller.scene_json()
  }
}

///|
#export_name("gpui_app_demo_state")
pub fn web_state() -> String {
  match web_runtime.val {
    None => "{\"ok\":false,\"error\":\"not_started\"}"
    Some(controller) => {
      let focus = match controller.tree.focused() {
        Some(value) => value.to_string()
        None => "null"
      }
      "{\"ok\":true,\"page\":\"\{controller.state.page.label()}\",\"status\":\"\{controller.state.status}\",\"clicks\":\{controller.state.clicks},\"note\":\"\{controller.state.note}\",\"accent\":\"\{controller.state.accent.label()}\",\"palette\":\{controller.palette.is_open()},\"focus\":\{focus}}"
    }
  }
}

///|
#export_name("gpui_app_demo_pointer_move")
pub fn web_pointer_move(x : Double, y : Double) -> String {
  let controller = match web_runtime.val {
    None => return "error:not_started"
    Some(value) => value
  }
  let point = match @primitives.Point::new(x, y) {
    Err(_) => return "error:invalid_point"
    Ok(value) => value
  }
  controller.pointer = Some(point)
  controller.hovered = controller.tree.hit_test(point)
  for kind in web_button_kinds() {
    match controller.button(kind) {
      Some(button) => {
        let (next, _) = button.handle_input(
          @primitives.PointerMoved(position=point),
        )
        controller.replace_button(next)
      }
      None => ()
    }
  }
  "ok"
}

///|
fn web_apply_button(
  controller : WebController,
  kind : @model.ButtonKind,
) -> Result[Unit, @diagnostics.FrameworkError] {
  match kind {
    @model.Increment => {
      ignore(controller.state.apply_intent(@model.Increment))
      controller.refresh_layout()
    }
    @model.Reset => {
      ignore(controller.state.apply_intent(@model.Reset))
      controller.refresh_layout()
    }
    @model.CycleAccent => {
      ignore(controller.state.apply_intent(@model.CycleAccent))
      Ok(())
    }
    @model.ToggleLoading => {
      ignore(controller.state.apply_intent(@model.ToggleLoading))
      Ok(())
    }
    @model.OpenPalette | @model.OpenPaletteCard => controller.open_palette()
    @model.Copy | @model.Disabled => Ok(())
  }
}

///|
#export_name("gpui_app_demo_pointer_down")
pub fn web_pointer_down(x : Double, y : Double) -> String {
  let controller = match web_runtime.val {
    None => return "error:not_started"
    Some(value) => value
  }
  let point = match @primitives.Point::new(x, y) {
    Err(_) => return "error:invalid_point"
    Ok(value) => value
  }
  if controller.palette.is_open() {
    if controller.layout.palette.field.contains(point) {
      let event = @primitives.PointerButtonPressed(
        position=point,
        button=@primitives.Primary,
        modifiers=@primitives.Modifiers::none(),
      )
      let measure = web_measure_text
      let admit = web_admit
      let hit = web_hit
      let handled = controller.palette.handle_input(event, measure, admit, hit)
      match handled {
        Err(_) => return "error:palette_input"
        Ok(value) =>
          match value.effect {
            @command_palette.Closed(epoch~, command_id=_) =>
              match controller.finish_palette_close(epoch) {
                Err(_) => return "error:palette_close"
                Ok(_) => ()
              }
            _ => ()
          }
      }
      return "ok"
    }
    if controller.layout.palette.panel.contains(point) {
      return "ok"
    }
    match controller.close_palette() {
      Err(_) => return "error:palette_close"
      Ok(_) => ()
    }
    return "ok"
  }
  let target = controller.tree.hit_test(point)
  match target {
    None => "ok"
    Some(id) =>
      match web_button_id(id) {
        Some(kind) =>
          match controller.button(kind) {
            Some(button) => {
              match controller.tree.with_focus(id) {
                Err(_) => ()
                Ok(value) => controller.tree = value
              }
              controller.sync_controls()
              let (next, _) = button.handle_input(
                @primitives.PointerButtonPressed(
                  position=point,
                  button=@primitives.Primary,
                  modifiers=@primitives.Modifiers::none(),
                ),
              )
              controller.replace_button(next)
              if kind == @model.OpenPalette || kind == @model.OpenPaletteCard {
                match controller.open_palette() {
                  Err(_) => return "error:palette_open"
                  Ok(_) => ()
                }
              }
              "ok"
            }
            None => "ok"
          }
        None =>
          if id == @model.NOTE_FIELD_ID {
            match controller.tree.with_focus(@model.NOTE_FIELD_ID) {
              Err(_) => ()
              Ok(value) => controller.tree = value
            }
            controller.sync_controls()
            let event = @primitives.PointerButtonPressed(
              position=point,
              button=@primitives.Primary,
              modifiers=@primitives.Modifiers::none(),
            )
            let handled = controller.note.handle_input(
              event, web_measure_text, web_admit, web_hit,
            )
            match handled {
              Err(_) => "error:note_input"
              Ok((candidate, action)) => {
                controller.note = candidate
                controller.state.note = controller.note.document().text()
                match action {
                  Some(_) => "ok"
                  None => "ok"
                }
              }
            }
          } else if id == 401UL {
            match controller.tree.with_focus(401UL) {
              Err(_) => ()
              Ok(value) => controller.tree = value
            }
            controller.sync_controls()
            match controller.layout.activity {
              Some(region) =>
                if region.viewport.contains(point) {
                  let offset = controller.state.scroll_activity.offset().y()
                  let local_y = point.y() - region.viewport.top() + offset
                  let index = (local_y / region.row_height).floor().to_int()
                  controller.state.select(@model.Activity, index)
                }
              None => ()
            }
            "ok"
          } else if id == 402UL {
            match controller.tree.with_focus(402UL) {
              Err(_) => ()
              Ok(value) => controller.tree = value
            }
            controller.sync_controls()
            match controller.layout.list {
              Some(region) =>
                if region.viewport.contains(point) {
                  let offset = controller.state.scroll_list.offset().y()
                  let local_y = point.y() - region.viewport.top() + offset
                  let index = (local_y / region.row_height).floor().to_int()
                  controller.state.select(@model.Items, index)
                }
              None => ()
            }
            "ok"
          } else if id >= 100UL && id < 104UL {
            let page = match @model.Page::from_index((id - 100UL).to_int()) {
              Some(value) => value
              None => return "ok"
            }
            controller.state.go(page)
            match controller.refresh_layout() {
              Err(_) => "error:layout"
              Ok(_) => {
                match controller.tree.with_focus(id) {
                  Err(_) => ()
                  Ok(value) => controller.tree = value
                }
                controller.sync_controls()
                "ok"
              }
            }
          } else {
            "ok"
          }
      }
  }
}

///|
#export_name("gpui_app_demo_pointer_up")
pub fn web_pointer_up(x : Double, y : Double) -> String {
  let controller = match web_runtime.val {
    None => return "error:not_started"
    Some(value) => value
  }
  let point = match @primitives.Point::new(x, y) {
    Err(_) => return "error:invalid_point"
    Ok(value) => value
  }
  if controller.palette.is_open() {
    return "ok"
  }
  for kind in web_button_kinds() {
    match controller.button(kind) {
      Some(button) => {
        let (next, result) = button.handle_input(
          @primitives.PointerButtonReleased(
            position=point,
            button=@primitives.Primary,
            modifiers=@primitives.Modifiers::none(),
          ),
        )
        controller.replace_button(next)
        if result.effect() == @button.Activated {
          match web_apply_button(controller, kind) {
            Err(_) => return "error:button"
            Ok(_) => ()
          }
        }
      }
      None => ()
    }
  }
  "ok"
}

///|
fn web_plain_text(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  for scalar in text.iter() {
    let value = scalar.to_int()
    if value < 0x20 || (value >= 0x7f && value <= 0x9f) {
      return false
    }
  }
  true
}

///|
#export_name("gpui_app_demo_text")
pub fn web_text(text : String) -> String {
  let controller = match web_runtime.val {
    None => return "error:not_started"
    Some(value) => value
  }
  if !web_plain_text(text) {
    return "ok"
  }
  if controller.palette.is_open() {
    let handled = controller.palette.handle_input(
      @primitives.TextInput(text~),
      web_measure_text,
      web_admit,
      web_hit,
    )
    match handled {
      Err(_) => "error:palette_input"
      Ok(_) => "ok"
    }
  } else if controller.tree.focused() == Some(@model.NOTE_FIELD_ID) {
    let handled = controller.note.handle_input(
      @primitives.TextInput(text~),
      web_measure_text,
      web_admit,
      web_hit,
    )
    match handled {
      Err(_) => "error:note_input"
      Ok((candidate, action)) => {
        controller.note = candidate
        controller.state.note = controller.note.document().text()
        match action {
          Some(@text_field.Submit) => {
            controller.state.record("Note submitted")
            controller.state.status = "Note submitted"
          }
          _ => ()
        }
        "ok"
      }
    }
  } else {
    "ok"
  }
}

///|
fn web_page_index(key : @primitives.Key) -> Int32? {
  match key {
    @primitives.Character(value) =>
      if value == "1" {
        Some(0)
      } else if value == "2" {
        Some(1)
      } else if value == "3" {
        Some(2)
      } else if value == "4" {
        Some(3)
      } else {
        None
      }
    _ => None
  }
}

///|
#export_name("gpui_app_demo_key")
pub fn web_key(key_name : String, modifiers : String, repeat : Bool) -> String {
  let controller = match web_runtime.val {
    None => return "error:not_started"
    Some(value) => value
  }
  let modifiers = web_modifiers(modifiers)
  let key = match web_key_value(key_name) {
    Some(value) => value
    None => return "ok"
  }
  let event = @primitives.KeyPressed(key~, modifiers~, repeat~)
  if controller.palette.is_open() {
    let handled = controller.palette.handle_input(
      event, web_measure_text, web_admit, web_hit,
    )
    match handled {
      Err(_) => return "error:palette_input"
      Ok(value) =>
        match value.effect {
          @command_palette.Closed(epoch~, command_id=_) =>
            match controller.finish_palette_close(epoch) {
              Err(_) => return "error:palette_close"
              Ok(_) => return "ok"
            }
          _ => return "ok"
        }
    }
  }
  if modifiers.meta() {
    if key == @primitives.Character("k") {
      match controller.open_palette() {
        Err(_) => return "error:palette_open"
        Ok(_) => return "ok"
      }
    }
    match web_page_index(key) {
      Some(index) => {
        match @model.Page::from_index(index) {
          Some(page) => {
            controller.state.go(page)
            match controller.refresh_layout() {
              Err(_) => return "error:layout"
              Ok(_) => ()
            }
          }
          None => ()
        }
        return "ok"
      }
      None => return "ok"
    }
  }
  if key == @primitives.Tab {
    let tree = if modifiers.shift() {
      controller.tree.focus_prev()
    } else {
      controller.tree.focus_next()
    }
    match tree {
      Err(_) => "error:focus"
      Ok(value) => {
        controller.tree = value
        controller.sync_controls()
        "ok"
      }
    }
  } else if controller.tree.focused() == Some(@model.NOTE_FIELD_ID) {
    let handled = controller.note.handle_input(
      event, web_measure_text, web_admit, web_hit,
    )
    match handled {
      Err(_) => "error:note_input"
      Ok((candidate, action)) => {
        controller.note = candidate
        controller.state.note = controller.note.document().text()
        match action {
          Some(@text_field.Submit) => {
            controller.state.record("Note submitted")
            controller.state.status = "Note submitted"
            "ok"
          }
          Some(@text_field.Blur) => {
            controller.tree = controller.tree.clear_focus()
            controller.sync_controls()
            "ok"
          }
          _ => "ok"
        }
      }
    }
  } else {
    match controller.tree.focused() {
      Some(id) =>
        match @model.ButtonKind::from_id(id) {
          Some(kind) =>
            match controller.button(kind) {
              Some(button) => {
                let (next, result) = button.handle_input(event)
                controller.replace_button(next)
                if result.effect() is @button.Activated {
                  match web_apply_button(controller, kind) {
                    Err(_) => return "error:button"
                    Ok(_) => ()
                  }
                }
                "ok"
              }
              None => "ok"
            }
          None =>
            if id == 401UL || id == 402UL {
              let kind = if id == 401UL {
                @model.Activity
              } else {
                @model.Items
              }
              match key {
                @primitives.ArrowDown =>
                  controller.state.move_selection(kind, 1)
                @primitives.ArrowUp => controller.state.move_selection(kind, -1)
                _ => ()
              }
              "ok"
            } else {
              "ok"
            }
        }
      None => "ok"
    }
  }
}

///|
fn web_modifiers(text : String) -> @primitives.Modifiers {
  @primitives.Modifiers::new(
    shift=text.contains("shift"),
    control=text.contains("ctrl"),
    alt=text.contains("alt"),
    meta=text.contains("meta"),
  )
}

///|
fn web_key_value(name : String) -> @primitives.Key? {
  match name {
    "Enter" => Some(@primitives.Enter)
    "Escape" => Some(@primitives.Escape)
    "Backspace" => Some(@primitives.Backspace)
    "Delete" => Some(@primitives.Delete)
    "Tab" => Some(@primitives.Tab)
    " " => Some(@primitives.Space)
    "ArrowLeft" => Some(@primitives.ArrowLeft)
    "ArrowRight" => Some(@primitives.ArrowRight)
    "ArrowUp" => Some(@primitives.ArrowUp)
    "ArrowDown" => Some(@primitives.ArrowDown)
    "Home" => Some(@primitives.Home)
    "End" => Some(@primitives.End)
    "PageUp" => Some(@primitives.PageUp)
    "PageDown" => Some(@primitives.PageDown)
    _ =>
      if name.length() == 1 {
        Some(@primitives.Character(name))
      } else {
        None
      }
  }
}

///|
#export_name("gpui_app_demo_scroll")
pub fn web_scroll(x : Double, y : Double, dx : Double, dy : Double) -> String {
  let controller = match web_runtime.val {
    None => return "error:not_started"
    Some(value) => value
  }
  let point = match @primitives.Point::new(x, y) {
    Err(_) => return "error:invalid_point"
    Ok(value) => value
  }
  let factor = if dy.abs() <= 3.0 { 24.0 } else { 1.0 }
  match controller.layout.activity {
    Some(region) =>
      if region.viewport.contains(point) {
        controller.state.scroll_by(@model.Activity, -dx, -dy * factor)
      }
    None => ()
  }
  match controller.layout.list {
    Some(region) =>
      if region.viewport.contains(point) {
        controller.state.scroll_by(@model.Items, -dx, -dy * factor)
      }
    None => ()
  }
  "ok"
}
