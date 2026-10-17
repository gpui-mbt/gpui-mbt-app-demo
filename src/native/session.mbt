///|
const ROOT_ID : UInt64 = 1UL

///|
const SIDEBAR_NODE_ID : UInt64 = 2UL

///|
const HEADER_NODE_ID : UInt64 = 3UL

///|
const CONTENT_NODE_ID : UInt64 = 4UL

///|
const NOTE_FIELD_ID : UInt64 = @model.NOTE_FIELD_ID

///|
const PALETTE_OVERLAY_ID : UInt64 = 9000UL

///|
const PALETTE_PANEL_ID : UInt64 = 9001UL

///|
const PALETTE_FIELD_ID : UInt64 = @model.PALETTE_FIELD_ID

///|
const NOTE_FONT_SIZE : Double = 16.0

///|
type DemoUnitResult = Result[Unit, @diagnostics.FrameworkError]

///|
type DemoEventOutcome = @gpui_app.EventOutcome

///|
type DemoEventResult = Result[DemoEventOutcome, @diagnostics.FrameworkError]

///|
type DemoSceneResult = Result[DemoSceneSnapshot, @diagnostics.FrameworkError]

///|
type DemoSceneSnapshot = @scene.SceneSnapshot

///|
type DemoTextField = @text_field.TextField

///|
type DemoPalette = @command_palette.CommandPalette

///|
type DemoDocument = @text.TextDocument

///|
fn demo_app_error(
  platform : DemoPlatform,
  operation : String,
  message : String,
) -> @diagnostics.FrameworkError {
  @diagnostics.FrameworkError::new(
    @diagnostics.InvalidInput,
    operation,
    subsystem="gpui-mbt-app-demo",
    backend=platform.backend_label,
    message~,
  )
}

///|
fn demo_text_document(
  platform : DemoPlatform,
  text : String,
) -> Result[DemoDocument, @diagnostics.FrameworkError] {
  match @text.TextDocument::new(text) {
    Ok(value) => Ok(value)
    Err(_) =>
      Err(demo_app_error(platform, "text_document", "malformed text document"))
  }
}

///|
fn demo_empty_field_rect() -> @primitives.Rect {
  @primitives.Rect::new(0.0, 0.0, 100.0, 40.0).unwrap()
}

///|
fn demo_empty_window_rect() -> @primitives.Rect {
  @primitives.Rect::new(0.0, 0.0, 1040.0, 720.0).unwrap()
}

///|
fn demo_nav_id(page : @model.Page) -> UInt64 {
  100UL + page.index().to_uint64()
}

///|
fn demo_list_id(kind : @model.ListKind) -> UInt64 {
  match kind {
    @model.Activity => 401UL
    @model.Items => 402UL
  }
}

///|
fn demo_list_kind(id : UInt64) -> @model.ListKind? {
  match id {
    401UL => Some(@model.Activity)
    402UL => Some(@model.Items)
    _ => None
  }
}

///|
fn demo_button_kind(id : UInt64) -> @model.ButtonKind? {
  @model.ButtonKind::from_id(id)
}

///|
fn demo_button_kinds() -> Array[@model.ButtonKind] {
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
/// One native window application. It owns shared controls and the element tree;
/// reusable scene/text/runtime mechanics live in gpui.mbt.
pub struct DemoSession {
  priv platform : DemoPlatform
  priv window : @platform.WindowId
  priv mut width : Double
  priv mut height : Double
  priv mut scale : Double
  priv state : @model.DemoState
  priv mut layout : @model.UiLayout
  priv mut note : @text_field.TextField
  priv mut palette : @command_palette.CommandPalette
  priv mut palette_field_rect : @primitives.Rect
  priv buttons : Array[@button.Button]
  priv mut tree : @element.ElementTree
  priv intents : Ref[Array[String]]
  priv mut modality : @element.InputModality
  priv mut hovered : UInt64?
  priv mut pointer : @primitives.Point?
  priv mut ax_binding : Int64
  priv mut ax_enabled : Bool
  priv mut closing : Bool
  priv mut smoke_enabled : Bool
  priv mut smoke_stage : Int32
  priv mut smoke_ticks : Int32
  priv mut smoke_shot : Int32
}

///|
fn demo_note_field(
  platform : DemoPlatform,
  bounds : @primitives.Rect,
) -> Result[DemoTextField, @diagnostics.FrameworkError] {
  let document = demo_text_document(platform, "")
  let doc = match document {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  match
    @text_field.TextField::new(
      NOTE_FIELD_ID,
      bounds,
      NOTE_FONT_SIZE,
      doc,
      platform.text.measure_document,
      platform.text.admit_document,
    ) {
    Ok(value) => Ok(value)
    Err(_) =>
      Err(
        demo_app_error(
          platform, "note_field", "TextField rejected the note field",
        ),
      )
  }
}

///|
fn demo_palette_field(
  platform : DemoPlatform,
  bounds : @primitives.Rect,
) -> Result[DemoTextField, @diagnostics.FrameworkError] {
  let document = demo_text_document(platform, "")
  let doc = match document {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  match
    @text_field.TextField::new(
      PALETTE_FIELD_ID,
      bounds,
      NOTE_FONT_SIZE,
      doc,
      platform.text.measure_document,
      platform.text.admit_document,
    ) {
    Ok(value) => Ok(value)
    Err(_) =>
      Err(
        demo_app_error(
          platform, "palette_field", "TextField rejected the palette field",
        ),
      )
  }
}

///|
fn demo_command_binding(
  id : String,
  label : String,
  intents : Ref[Array[String]],
) -> @capability.GuiBinding[Unit, Unit] {
  let descriptor = @capability.Descriptor::new(
    id,
    label,
    "gpui-mbt-app-demo",
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
fn demo_commands(
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
        demo_command_binding(id, label, intents),
      ),
    )
  }
  commands
}

///|
fn demo_create_palette(
  platform : DemoPlatform,
  bounds : @primitives.Rect,
  intents : Ref[Array[String]],
) -> Result[DemoPalette, @diagnostics.FrameworkError] {
  let field = demo_palette_field(platform, bounds)
  let field = match field {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  match @command_palette.CommandPalette::new(field, demo_commands(intents)) {
    Ok(value) => Ok(value)
    Err(_) =>
      Err(
        demo_app_error(
          platform, "palette", "CommandPalette rejected demo commands",
        ),
      )
  }
}

///|
fn demo_placeholder_tree() -> @element.ElementTree {
  match
    @element.ElementTree::new([
      @element.ElementNode::new(ROOT_ID, None, demo_empty_window_rect()),
    ]) {
    Ok(value) => value
    Err(_) => abort("root element node was rejected")
  }
}

///|
pub fn DemoSession::new(
  platform : DemoPlatform,
  window : @platform.WindowId,
  width : Double,
  height : Double,
  scale : Double,
) -> Result[DemoSession, @diagnostics.FrameworkError] {
  let state = @model.DemoState::new()
  let layout = @model.layout(state, width, height)
  let note_bounds = match layout.note_field {
    Some(value) => value.bounds
    None => demo_empty_field_rect()
  }
  let note = match demo_note_field(platform, note_bounds) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let intents : Ref[Array[String]] = Ref([])
  let palette = match
    demo_create_palette(platform, layout.palette.field, intents) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let buttons : Array[@button.Button] = []
  for kind in demo_button_kinds() {
    let button = match
      @button.Button::new(kind.id(), demo_empty_field_rect(), kind.label()) {
      Ok(value) => value
      Err(_) =>
        return Err(
          demo_app_error(platform, "button", "Button rejected a demo action"),
        )
    }
    if kind == @model.Disabled {
      buttons.push(button.with_enabled(false))
    } else {
      buttons.push(button)
    }
  }
  let ax_enabled = platform.ax is Some(_)
  let session = {
    platform,
    window,
    width,
    height,
    scale,
    state,
    layout,
    note,
    palette,
    palette_field_rect: layout.palette.field,
    buttons,
    tree: demo_placeholder_tree(),
    intents,
    modality: @element.InputModality::Mouse,
    hovered: None,
    pointer: None,
    ax_binding: 0L,
    ax_enabled,
    closing: false,
    smoke_enabled: false,
    smoke_stage: 0,
    smoke_ticks: 0,
    smoke_shot: 0,
  }
  match session.refresh_layout() {
    Err(error) => Err(error)
    Ok(_) => Ok(session)
  }
}

///|
pub fn DemoSession::set_smoke(self : DemoSession, enabled : Bool) -> Unit {
  self.smoke_enabled = enabled
}

///|
pub fn DemoSession::window(self : DemoSession) -> @platform.WindowId {
  self.window
}

///|
pub fn[B : @platform.Backend] DemoSession::run_on(
  self : DemoSession,
  host : B,
  window : @platform.WindowId,
  timeout_ms~ : Int32 = 16,
  max_ticks~ : Int32? = None,
  present_on_start~ : Bool = false,
) -> Result[@gpui_app.WindowRunOutcome, @diagnostics.FrameworkError] {
  @gpui_app.run_window(
    host,
    window,
    self,
    timeout_ms~,
    max_ticks~,
    present_on_start~,
  )
}

///|
fn DemoSession::button(
  self : DemoSession,
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
fn DemoSession::replace_button(
  self : DemoSession,
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
fn DemoSession::rebuild_palette(self : DemoSession) -> DemoUnitResult {
  let palette = demo_create_palette(
    self.platform,
    self.layout.palette.field,
    self.intents,
  )
  match palette {
    Err(error) => Err(error)
    Ok(value) => {
      self.palette = value
      self.palette_field_rect = self.layout.palette.field
      Ok(())
    }
  }
}

///|
fn DemoSession::sync_controls(self : DemoSession) -> Unit {
  let focused = self.tree.focused()
  for kind in demo_button_kinds() {
    let button = match self.button(kind) {
      Some(value) => value
      None => continue
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
  let note_focused = focused == Some(NOTE_FIELD_ID) && !self.palette.is_open()
  let note = self.note
  match note.with_focus(note_focused) {
    Err(_) => ()
    Ok(value) => self.note = value
  }
}

///|
fn DemoSession::make_tree(
  self : DemoSession,
  focus_hint : UInt64?,
  include_palette : Bool,
) -> Result[@element.ElementTree, @diagnostics.FrameworkError] {
  let nodes : Array[@element.ElementNode] = []
  nodes.push(@element.ElementNode::new(ROOT_ID, None, self.layout.viewport))
  nodes.push(
    @element.ElementNode::new(
      SIDEBAR_NODE_ID,
      Some(ROOT_ID),
      self.layout.sidebar,
    ),
  )
  for region in self.layout.nav {
    nodes.push(
      @element.ElementNode::new(region.id, Some(SIDEBAR_NODE_ID), region.bounds).with_focusable(
        true,
      ),
    )
  }
  nodes.push(
    @element.ElementNode::new(HEADER_NODE_ID, Some(ROOT_ID), self.layout.header),
  )
  let palette_button = match self.button(@model.OpenPalette) {
    Some(value) => value
    None =>
      return Err(
        demo_app_error(self.platform, "tree", "missing palette button"),
      )
  }
  nodes.push(palette_button.element_node(Some(HEADER_NODE_ID)))
  nodes.push(
    @element.ElementNode::new(
      CONTENT_NODE_ID,
      Some(ROOT_ID),
      self.layout.content,
    ),
  )
  match self.layout.note_field {
    Some(region) => {
      let note = self.note
      nodes.push(note.element_node(Some(CONTENT_NODE_ID)))
      ignore(region)
    }
    None => ()
  }
  for region in self.layout.buttons {
    match demo_button_kind(region.id) {
      Some(kind) =>
        match self.button(kind) {
          Some(button) => nodes.push(button.element_node(Some(CONTENT_NODE_ID)))
          None => ()
        }
      None => ()
    }
  }
  match self.layout.activity {
    Some(region) =>
      nodes.push(
        @element.ElementNode::new(
          demo_list_id(@model.Activity),
          Some(CONTENT_NODE_ID),
          region.viewport,
        ).with_focusable(true),
      )
    None => ()
  }
  match self.layout.list {
    Some(region) =>
      nodes.push(
        @element.ElementNode::new(
          demo_list_id(@model.Items),
          Some(CONTENT_NODE_ID),
          region.viewport,
        ).with_focusable(true),
      )
    None => ()
  }
  if include_palette {
    nodes.push(
      @element.ElementNode::new(
        PALETTE_OVERLAY_ID,
        Some(ROOT_ID),
        self.layout.palette.overlay,
      ),
    )
    nodes.push(
      @element.ElementNode::new(
        PALETTE_PANEL_ID,
        Some(PALETTE_OVERLAY_ID),
        self.layout.palette.panel,
      ),
    )
    nodes.push(
      @element.ElementNode::new(
        PALETTE_FIELD_ID,
        Some(PALETTE_PANEL_ID),
        self.layout.palette.field,
      ).with_focusable(true),
    )
  }
  let tree = match @element.ElementTree::new(nodes) {
    Ok(value) => value
    Err(_) =>
      return Err(
        demo_app_error(
          self.platform,
          "tree",
          "element tree rejected the demo layout",
        ),
      )
  }
  let fallback = if include_palette {
    PALETTE_FIELD_ID
  } else if self.layout.note_field is Some(_) {
    NOTE_FIELD_ID
  } else {
    demo_nav_id(self.state.page)
  }
  let target = match focus_hint {
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
fn DemoSession::refresh_layout(self : DemoSession) -> DemoUnitResult {
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
  for kind in demo_button_kinds() {
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
  let current = self.tree.focused()
  let tree = self.make_tree(current, self.palette.is_open())
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
fn DemoSession::sync_metrics(
  self : DemoSession,
  metrics : @gpui_app.WindowMetrics,
) -> DemoUnitResult {
  self.width = metrics.width
  self.height = metrics.height
  self.scale = metrics.scale
  Ok(())
}

///|
fn DemoSession::palette_measure(
  self : DemoSession,
) -> (@text.TextDocument) -> Result[
  @text_layout.TextMeasurement,
  @text_field.TextFieldError,
] {
  self.platform.text.measure_document
}

///|
fn DemoSession::palette_admit(
  self : DemoSession,
) -> (@text.TextDocument, @text_layout.TextMeasurement) -> Result[
  Unit,
  @text_field.TextFieldError,
] {
  self.platform.text.admit_document
}

///|
fn DemoSession::palette_hit(
  self : DemoSession,
) -> (@text.TextDocument, @primitives.Point) -> Result[
  @text_layout.TextHit,
  @text_field.TextFieldError,
] {
  self.platform.text.hit_document
}

///|
fn DemoSession::note_action(
  self : DemoSession,
  action : @text_field.TextFieldAction,
) -> DemoUnitResult {
  match action {
    @text_field.Copy(text) => ignore(self.copy_text(text))
    @text_field.Cut(text=selected, candidate~) =>
      if self.copy_text(selected) {
        self.note = candidate
        self.state.note = self.note.document().text()
        self.state.record("Cut note selection")
      }
    @text_field.Paste =>
      match self.paste_text() {
        None => ()
        Some(text) => {
          let measure = self.palette_measure()
          let admit = self.palette_admit()
          match self.note.replace_selection(text, measure, admit) {
            Err(_) => self.state.set_status("Paste was rejected")
            Ok(value) => {
              self.note = value
              self.state.note = self.note.document().text()
              self.state.status = "Pasted into note"
            }
          }
        }
      }
    @text_field.Submit => {
      self.state.note = self.note.document().text()
      self.state.record("Note submitted")
      self.state.status = "Note submitted"
    }
    @text_field.Blur => {
      self.tree = self.tree.clear_focus()
      self.sync_controls()
    }
  }
  Ok(())
}

///|
fn DemoSession::palette_action(
  self : DemoSession,
  action : @text_field.TextFieldAction,
) -> DemoUnitResult {
  match action {
    @text_field.Copy(text) => ignore(self.copy_text(text))
    @text_field.Cut(text=selected, candidate~) =>
      if self.copy_text(selected) {
        match self.palette.install_field(candidate) {
          Ok(_) => ()
          Err(_) => self.state.set_status("Palette cut was rejected")
        }
      }
    @text_field.Paste =>
      match self.paste_text() {
        None => ()
        Some(text) => {
          let field = self.palette.field()
          let measure = self.palette_measure()
          let admit = self.palette_admit()
          match field.replace_selection(text, measure, admit) {
            Err(_) => self.state.set_status("Paste was rejected")
            Ok(value) =>
              match self.palette.install_field(value) {
                Ok(_) => self.state.status = "Pasted into palette"
                Err(_) => self.state.set_status("Palette paste was rejected")
              }
          }
        }
      }
    @text_field.Submit | @text_field.Blur => ()
  }
  Ok(())
}

///|
fn DemoSession::finish_palette_close(
  self : DemoSession,
  epoch : Int32,
) -> DemoBoolResult {
  let tree_ref = Ref(self.tree)
  match self.palette.finish_close(epoch, tree_ref) {
    Err(_) =>
      return Err(
        demo_app_error(
          self.platform,
          "palette_close",
          "palette could not finish closing",
        ),
      )
    Ok(_) => ()
  }
  self.tree = tree_ref.val
  self.palette.retire_key_guard(epoch)
  match self.drain_intents() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  Ok(true)
}

///|
fn DemoSession::close_palette(self : DemoSession) -> DemoBoolResult {
  if !self.palette.is_open() {
    return Ok(false)
  }
  match self.palette.blur() {
    Err(_) =>
      Err(
        demo_app_error(
          self.platform,
          "palette_close",
          "palette blur was rejected",
        ),
      )
    Ok(effect) =>
      match effect {
        @command_palette.Closed(epoch~, command_id=_) =>
          self.finish_palette_close(epoch)
        _ => Ok(false)
      }
  }
}

///|
fn DemoSession::open_palette(self : DemoSession) -> DemoBoolResult {
  if self.palette.is_open() {
    return Ok(true)
  }
  match self.note.with_focus(false) {
    Err(_) => ()
    Ok(value) => self.note = value
  }
  let current = self.tree.focused()
  let tree = self.make_tree(current, true)
  let tree = match tree {
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
      Err(
        demo_app_error(
          self.platform,
          "palette_open",
          "CommandPalette refused to open",
        ),
      )
    }
    Ok(_) => {
      self.tree = tree_ref.val
      self.sync_controls()
      Ok(true)
    }
  }
}

///|
fn DemoSession::handle_palette_input(
  self : DemoSession,
  event : @primitives.InputEvent,
) -> DemoBoolResult {
  let measure = self.palette_measure()
  let admit = self.palette_admit()
  let hit = self.palette_hit()
  let input = match demo_palette_text(event) {
    Some(text) => @primitives.TextInput(text~)
    None => event
  }
  let handled = match self.palette.handle_input(input, measure, admit, hit) {
    Err(_) =>
      return Err(
        demo_app_error(self.platform, "palette_input", "palette rejected input"),
      )
    Ok(value) => value
  }
  match handled.effect {
    @command_palette.Closed(epoch~, command_id=_) =>
      match self.finish_palette_close(epoch) {
        Err(error) => Err(error)
        Ok(_) => Ok(true)
      }
    @command_palette.FieldAction(action) =>
      match self.palette_action(action) {
        Err(error) => Err(error)
        Ok(_) => Ok(true)
      }
    @command_palette.CompositionCancelled => Ok(true)
    @command_palette.None => Ok(handled.consumed)
  }
}

///|
fn DemoSession::drain_intents(self : DemoSession) -> DemoUnitResult {
  let pending = self.intents.val
  self.intents.val = []
  let mut focus_note = false
  for id in pending {
    self.state.palette_actions += 1
    match id {
      "demo.go_overview" => self.state.go(@model.Overview)
      "demo.go_controls" => self.state.go(@model.Controls)
      "demo.go_lists" => self.state.go(@model.Lists)
      "demo.go_about" => self.state.go(@model.About)
      "demo.increment" => ignore(self.state.apply_intent(@model.Increment))
      "demo.reset" => ignore(self.state.apply_intent(@model.Reset))
      "demo.copy" => ignore(self.copy_summary())
      "demo.toggle_loading" =>
        ignore(self.state.apply_intent(@model.ToggleLoading))
      "demo.cycle_accent" => ignore(self.state.apply_intent(@model.CycleAccent))
      "demo.focus_note" => focus_note = true
      "demo.quit" => {
        self.closing = true
        match (self.platform.host.request_exit)() {
          Err(error) =>
            self.state.set_status("Exit failed: " + error.code().label())
          Ok(_) => self.state.set_status("Quit requested")
        }
      }
      _ => self.state.set_status("Unknown command")
    }
  }
  match self.refresh_layout() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if focus_note && !self.closing {
    self.focus_node(NOTE_FIELD_ID)
  }
  Ok(())
}

///|
fn DemoSession::copy_text(self : DemoSession, text : String) -> Bool {
  match (self.platform.host.write_clipboard)(text) {
    Err(error) => {
      self.state.set_status("Clipboard error: " + error.code().label())
      false
    }
    Ok(_) => {
      self.state.set_status("Copied to clipboard")
      true
    }
  }
}

///|
fn DemoSession::copy_summary(self : DemoSession) -> Bool {
  let text = self.state.summary()
  self.copy_text(text)
}

///|
fn DemoSession::paste_text(self : DemoSession) -> String? {
  match (self.platform.host.read_clipboard)() {
    Err(error) => {
      self.state.set_status("Clipboard error: " + error.code().label())
      None
    }
    Ok(text) => Some(text)
  }
}

///|
fn DemoSession::apply_button_action(
  self : DemoSession,
  kind : @model.ButtonKind,
) -> DemoUnitResult {
  match kind {
    @model.Increment => {
      ignore(self.state.apply_intent(@model.Increment))
      match self.refresh_layout() {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
    }
    @model.Reset => {
      ignore(self.state.apply_intent(@model.Reset))
      match self.refresh_layout() {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
    }
    @model.Copy => ignore(self.copy_summary())
    @model.CycleAccent => ignore(self.state.apply_intent(@model.CycleAccent))
    @model.ToggleLoading =>
      ignore(self.state.apply_intent(@model.ToggleLoading))
    @model.OpenPalette | @model.OpenPaletteCard => self.open_palette_quiet()
    @model.Disabled => ()
  }
  self.sync_controls()
  Ok(())
}

///|
fn DemoSession::publish_ax(self : DemoSession) -> Unit {
  if !self.ax_enabled {
    return
  }
  let ax = match self.platform.ax {
    None => return
    Some(value) => value
  }
  let region = match self.layout.button(@model.Increment) {
    Some(value) => value
    None => {
      self.revoke_ax()
      return
    }
  }
  let button = match self.button(@model.Increment) {
    Some(value) => value
    None => return
  }
  match
    (ax.publish)(
      self.ax_binding,
      "Increment counter",
      region.bounds,
      button.is_enabled(),
      button.is_loading(),
      button.is_focused(),
      self.state.clicks,
    ) {
    Err(error) => {
      self.ax_enabled = false
      self.ax_binding = 0L
      self.state.set_status("AX unavailable: " + error.code().label())
    }
    Ok(binding) => self.ax_binding = binding
  }
}

///|
fn DemoSession::revoke_ax(self : DemoSession) -> Unit {
  if self.ax_binding != 0L {
    match self.platform.ax {
      Some(ax) => (ax.revoke)(self.ax_binding)
      None => ()
    }
    self.ax_binding = 0L
  }
}

///|
fn DemoSession::poll_ax(self : DemoSession) -> Bool {
  if !self.ax_enabled || self.ax_binding == 0L {
    return false
  }
  let ax = match self.platform.ax {
    None => return false
    Some(value) => value
  }
  match (ax.take_request)() {
    Err(_) => {
      self.ax_enabled = false
      false
    }
    Ok(None) => false
    Ok(Some(token)) =>
      if token == self.ax_binding {
        ignore(self.state.apply_intent(@model.Increment))
        ignore(self.refresh_layout())
        true
      } else {
        false
      }
  }
}

///|
fn DemoSession::focus_node(self : DemoSession, id : UInt64) -> Unit {
  match self.tree.with_focus(id) {
    Err(_) => self.state.set_status("Focus target is unavailable")
    Ok(value) => {
      self.tree = value
      self.sync_controls()
    }
  }
}

///|
impl @gpui_app.WindowView for DemoSession with fn handle_event(
  self,
  event,
  metrics,
) -> DemoEventResult {
  match self.sync_metrics(metrics) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match event.kind() {
    @platform.Created => {
      match self.refresh_layout() {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      Ok(@gpui_app.EventOutcome::repaint())
    }
    @platform.Resized(width=_, height=_) | @platform.ScaleChanged => {
      if self.palette.is_open() {
        match self.close_palette() {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
      }
      match self.refresh_layout() {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      Ok(@gpui_app.EventOutcome::repaint())
    }
    @platform.FocusChanged(false) => {
      if self.palette.is_open() {
        match self.close_palette() {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
      }
      self.tree = self.tree.clear_focus()
      self.sync_controls()
      Ok(@gpui_app.EventOutcome::repaint())
    }
    @platform.FocusChanged(true) => Ok(@gpui_app.EventOutcome::repaint())
    @platform.VisibilityChanged(true) => Ok(@gpui_app.EventOutcome::repaint())
    @platform.Input(input) => {
      let consumed = match self.handle_input(input) {
        Err(error) => return Err(error)
        Ok(value) => value
      }
      if consumed {
        Ok(@gpui_app.EventOutcome::repaint())
      } else {
        Ok(@gpui_app.EventOutcome::none())
      }
    }
    @platform.CloseRequested => {
      self.revoke_ax()
      self.closing = true
      Ok(@gpui_app.EventOutcome::close())
    }
    @platform.ExitRequested => {
      self.revoke_ax()
      self.closing = true
      Ok(@gpui_app.EventOutcome::exit())
    }
    @platform.Wake => Ok(@gpui_app.EventOutcome::repaint())
    _ => Ok(@gpui_app.EventOutcome::none())
  }
}

///|
impl @gpui_app.WindowView for DemoSession with fn scene(self, metrics) -> DemoSceneResult {
  self.build_scene(metrics)
}

///|
impl @gpui_app.WindowView for DemoSession with fn after_present(self, metrics) -> DemoEventResult {
  self.publish_ax()
  if self.smoke_enabled {
    match self.smoke_after_present(metrics) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
  }
  Ok(@gpui_app.EventOutcome::none())
}

///|
impl @gpui_app.WindowView for DemoSession with fn on_idle(self, metrics) -> DemoEventResult {
  ignore(metrics)
  if self.smoke_enabled {
    match self.smoke_on_idle() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
  }
  if self.poll_ax() {
    Ok(@gpui_app.EventOutcome::repaint())
  } else {
    Ok(@gpui_app.EventOutcome::none())
  }
}

///|
fn DemoSession::open_palette_quiet(self : DemoSession) -> Unit {
  match self.open_palette() {
    Err(error) => self.state.set_status(error.code().label())
    Ok(_) => ()
  }
}
