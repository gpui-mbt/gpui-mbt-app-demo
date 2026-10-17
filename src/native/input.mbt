///|
type DemoBoolResult = Result[Bool, @diagnostics.FrameworkError]

///|
fn demo_printable_text(text : String) -> Bool {
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
fn demo_plain_key_text(input : @primitives.InputEvent) -> String? {
  match input {
    @primitives.KeyPressed(
      key=@primitives.Character(value),
      modifiers~,
      repeat=_
    ) =>
      if !modifiers.control() &&
        !modifiers.meta() &&
        !modifiers.alt() &&
        demo_printable_text(value) {
        Some(value)
      } else {
        None
      }
    @primitives.KeyPressed(key=@primitives.Space, modifiers~, repeat=_) =>
      if !modifiers.control() && !modifiers.meta() && !modifiers.alt() {
        Some(" ")
      } else {
        None
      }
    _ => None
  }
}

///|
fn demo_palette_text(input : @primitives.InputEvent) -> String? {
  match demo_plain_key_text(input) {
    Some(text) => Some(text.to_lower())
    None => None
  }
}

///|
fn demo_key_shift(input : @primitives.InputEvent) -> Bool {
  match input {
    @primitives.KeyPressed(modifiers~, ..) => modifiers.shift()
    _ => false
  }
}

///|
fn demo_key_letter_meta(
  input : @primitives.InputEvent,
  letter : String,
) -> Bool {
  match input {
    @primitives.KeyPressed(
      key=@primitives.Character(value),
      modifiers~,
      repeat=_
    ) =>
      (modifiers.meta() || modifiers.control()) &&
      !modifiers.alt() &&
      value.to_lower() == letter
    _ => false
  }
}

///|
fn DemoSession::handle_input(
  self : DemoSession,
  input : @primitives.InputEvent,
) -> DemoBoolResult {
  self.modality = self.modality.after_input(input)
  match input {
    @primitives.KeyPressed(..)
    | @primitives.KeyReleased(..)
    | @primitives.TextInput(..) => self.handle_key(input)
    @primitives.PointerMoved(position~) => self.handle_pointer_move(position)
    @primitives.PointerButtonPressed(position~, button~, modifiers~) =>
      self.handle_pointer_press(position, button, modifiers)
    @primitives.PointerButtonReleased(position~, ..) =>
      self.handle_pointer_release(position)
    @primitives.Scroll(position~, delta~, ..) =>
      self.handle_scroll(position, delta)
  }
}

///|
fn DemoSession::handle_key(
  self : DemoSession,
  input : @primitives.InputEvent,
) -> DemoBoolResult {
  // Host-level quit/close shortcuts take precedence, even while a palette is open.
  if demo_key_letter_meta(input, "q") {
    self.closing = true
    match (self.platform.host.request_exit)() {
      Err(error) =>
        self.state.set_status("Exit failed: " + error.code().label())
      Ok(_) => self.state.set_status("Quit requested")
    }
    return Ok(true)
  }
  if demo_key_letter_meta(input, "w") {
    self.closing = true
    match (self.platform.host.request_close)() {
      Err(error) =>
        self.state.set_status("Close failed: " + error.code().label())
      Ok(_) => self.state.set_status("Close requested")
    }
    return Ok(true)
  }
  if self.palette.is_open() {
    return self.handle_palette_input(input)
  }
  if demo_key_letter_meta(input, "k") {
    self.open_palette_quiet()
    return Ok(true)
  }
  if demo_key_letter_meta(input, "c") {
    if self.tree.focused() != Some(NOTE_FIELD_ID) {
      ignore(self.copy_summary())
      return Ok(true)
    }
  }
  for
    (letter, page, index) in [
      ("1", @model.Overview, 0),
      ("2", @model.Controls, 1),
      ("3", @model.Lists, 2),
      ("4", @model.About, 3),
    ] {
    ignore(index)
    if demo_key_letter_meta(input, letter) {
      self.state.go(page)
      match self.refresh_layout() {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      return Ok(true)
    }
  }
  if demo_key_letter_meta(input, "r") && demo_key_shift(input) {
    ignore(self.state.apply_intent(@model.Reset))
    match self.refresh_layout() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    return Ok(true)
  }
  match input {
    @primitives.KeyPressed(key=@primitives.Tab, modifiers~, repeat=_) => {
      let tree = if modifiers.shift() {
        self.tree.focus_prev()
      } else {
        self.tree.focus_next()
      }
      match tree {
        Err(_) => self.state.set_status("No focus target")
        Ok(value) => {
          self.tree = value
          self.sync_controls()
        }
      }
      return Ok(true)
    }
    _ => ()
  }
  if self.tree.focused() == Some(NOTE_FIELD_ID) {
    match self.handle_note_key(input) {
      Err(error) => Err(error)
      Ok(consumed) =>
        if consumed {
          Ok(true)
        } else {
          self.handle_focused_key(input)
        }
    }
  } else {
    self.handle_focused_key(input)
  }
}

///|
fn DemoSession::handle_note_key(
  self : DemoSession,
  input : @primitives.InputEvent,
) -> DemoBoolResult {
  let event = match demo_plain_key_text(input) {
    Some(text) => @primitives.TextInput(text~)
    None => input
  }
  let measure = self.palette_measure()
  let admit = self.palette_admit()
  let hit = self.palette_hit()
  let handled = match self.note.handle_input(event, measure, admit, hit) {
    Err(_) =>
      return Err(
        demo_app_error(self.platform, "note_input", "TextField rejected input"),
      )
    Ok(value) => value
  }
  let (candidate, action) = handled
  self.note = candidate
  self.state.note = self.note.document().text()
  match action {
    Some(value) =>
      match self.note_action(value) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
    None => ()
  }
  Ok(true)
}

///|
fn DemoSession::handle_focused_key(
  self : DemoSession,
  input : @primitives.InputEvent,
) -> DemoBoolResult {
  let focused = self.tree.focused()
  let id = match focused {
    None => return Ok(false)
    Some(value) => value
  }
  match demo_button_kind(id) {
    Some(kind) => {
      let button = match self.button(kind) {
        None => return Ok(false)
        Some(value) => value
      }
      let (next, result) = button.handle_input(input)
      self.replace_button(next)
      if result.effect() == @button.Activated {
        match self.apply_button_action(kind) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
      }
      return Ok(result.consumed())
    }
    None => ()
  }
  match demo_list_kind(id) {
    Some(list) => return self.handle_list_key(list, input)
    None => ()
  }
  self.handle_nav_key(id, input)
}

///|
fn DemoSession::handle_list_key(
  self : DemoSession,
  list : @model.ListKind,
  input : @primitives.InputEvent,
) -> DemoBoolResult {
  match input {
    @primitives.KeyPressed(key=@primitives.ArrowDown, modifiers~, repeat=_) => {
      ignore(modifiers)
      self.state.move_selection(list, 1)
      Ok(true)
    }
    @primitives.KeyPressed(key=@primitives.ArrowUp, modifiers~, repeat=_) => {
      ignore(modifiers)
      self.state.move_selection(list, -1)
      Ok(true)
    }
    @primitives.KeyPressed(key=@primitives.PageDown, modifiers~, repeat=_) => {
      ignore(modifiers)
      self.state.move_selection(list, 5)
      Ok(true)
    }
    @primitives.KeyPressed(key=@primitives.PageUp, modifiers~, repeat=_) => {
      ignore(modifiers)
      self.state.move_selection(list, -5)
      Ok(true)
    }
    @primitives.KeyPressed(key=@primitives.Home, modifiers~, repeat=_) => {
      ignore(modifiers)
      self.state.select(list, 0)
      Ok(true)
    }
    @primitives.KeyPressed(key=@primitives.End, modifiers~, repeat=_) => {
      ignore(modifiers)
      let count = match list {
        @model.Activity => self.state.activity_count()
        @model.Items => @model.LIST_ROWS
      }
      self.state.select(list, count - 1)
      Ok(true)
    }
    _ => Ok(false)
  }
}

///|
fn DemoSession::handle_nav_key(
  self : DemoSession,
  id : UInt64,
  input : @primitives.InputEvent,
) -> DemoBoolResult {
  let index = if id >= 100UL && id < 104UL {
    (id - 100UL).to_int()
  } else {
    return Ok(false)
  }
  match input {
    @primitives.KeyPressed(key=@primitives.ArrowDown, modifiers~, repeat=_) => {
      ignore(modifiers)
      self.go_page_index((index + 1) % 4)
      Ok(true)
    }
    @primitives.KeyPressed(key=@primitives.ArrowUp, modifiers~, repeat=_) => {
      ignore(modifiers)
      self.go_page_index((index + 3) % 4)
      Ok(true)
    }
    @primitives.KeyPressed(key=@primitives.Enter, modifiers~, repeat=_)
    | @primitives.KeyPressed(key=@primitives.Space, modifiers~, repeat=_) => {
      ignore(modifiers)
      self.go_page_index(index)
      Ok(true)
    }
    _ => Ok(false)
  }
}

///|
fn DemoSession::go_page_index(self : DemoSession, index : Int32) -> Unit {
  match @model.Page::from_index(index) {
    Some(page) => {
      self.state.go(page)
      match self.refresh_layout() {
        Err(error) => self.state.set_status(error.code().label())
        Ok(_) => self.focus_node(demo_nav_id(page))
      }
    }
    None => ()
  }
}

///|
fn DemoSession::handle_pointer_move(
  self : DemoSession,
  point : @primitives.Point,
) -> DemoBoolResult {
  self.pointer = Some(point)
  let before = self.hovered
  let target = self.tree.hit_test(point)
  self.hovered = target
  let mut changed = before != target
  for kind in demo_button_kinds() {
    match self.button(kind) {
      Some(button) => {
        let hovered_before = button.is_hovered()
        let (next, _) = button.handle_input(
          @primitives.PointerMoved(position=point),
        )
        self.replace_button(next)
        if next.is_hovered() != hovered_before {
          changed = true
        }
      }
      None => ()
    }
  }
  ignore(self.apply_cursor(point))
  Ok(changed)
}

///|
fn DemoSession::handle_pointer_press(
  self : DemoSession,
  point : @primitives.Point,
  button : @primitives.MouseButton,
  modifiers : @primitives.Modifiers,
) -> DemoBoolResult {
  if self.palette.is_open() {
    if self.layout.palette.field.contains(point) {
      return self.handle_palette_input(
        @primitives.PointerButtonPressed(position=point, button~, modifiers~),
      )
    }
    if self.layout.palette.panel.contains(point) {
      return Ok(true)
    }
    match self.close_palette() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    return Ok(true)
  }
  let target = self.tree.hit_test(point)
  match target {
    None => Ok(false)
    Some(id) =>
      if id == PALETTE_OVERLAY_ID {
        Ok(false)
      } else if id == PALETTE_PANEL_ID {
        Ok(true)
      } else if id == NOTE_FIELD_ID {
        self.focus_node(NOTE_FIELD_ID)
        let measure = self.palette_measure()
        let admit = self.palette_admit()
        let hit = self.palette_hit()
        let event = @primitives.PointerButtonPressed(
          position=point,
          button~,
          modifiers~,
        )
        match self.note.handle_input(event, measure, admit, hit) {
          Err(_) => Ok(true)
          Ok((candidate, action)) => {
            self.note = candidate
            self.state.note = self.note.document().text()
            match action {
              Some(value) =>
                match self.note_action(value) {
                  Err(error) => return Err(error)
                  Ok(_) => ()
                }
              None => ()
            }
            Ok(true)
          }
        }
      } else {
        match demo_button_kind(id) {
          Some(kind) =>
            match self.button(kind) {
              Some(value) => {
                self.focus_node(id)
                let (next, _) = value.handle_input(
                  @primitives.PointerButtonPressed(
                    position=point,
                    button~,
                    modifiers~,
                  ),
                )
                self.replace_button(next)
                if kind == @model.OpenPalette || kind == @model.OpenPaletteCard {
                  self.open_palette_quiet()
                }
                Ok(true)
              }
              None => Ok(false)
            }
          None =>
            match demo_list_kind(id) {
              Some(list) => {
                self.focus_node(id)
                self.select_row_at(list, point)
                Ok(true)
              }
              None =>
                if id >= 100UL && id < 104UL {
                  let index = (id - 100UL).to_int()
                  self.go_page_index(index)
                  Ok(true)
                } else {
                  Ok(false)
                }
            }
        }
      }
  }
}

///|
fn DemoSession::handle_pointer_release(
  self : DemoSession,
  point : @primitives.Point,
) -> DemoBoolResult {
  if self.palette.is_open() {
    return Ok(true)
  }
  let mut consumed = false
  for kind in demo_button_kinds() {
    match self.button(kind) {
      Some(button) => {
        let (next, result) = button.handle_input(
          @primitives.PointerButtonReleased(
            position=point,
            button=@primitives.Primary,
            modifiers=@primitives.Modifiers::none(),
          ),
        )
        self.replace_button(next)
        if result.consumed() {
          consumed = true
        }
        if result.effect() == @button.Activated {
          match self.apply_button_action(kind) {
            Err(error) => return Err(error)
            Ok(_) => ()
          }
        }
      }
      None => ()
    }
  }
  Ok(consumed)
}

///|
fn DemoSession::select_row_at(
  self : DemoSession,
  list : @model.ListKind,
  point : @primitives.Point,
) -> Unit {
  let region = match list {
    @model.Activity => self.layout.activity
    @model.Items => self.layout.list
  }
  match region {
    None => ()
    Some(value) =>
      if value.viewport.contains(point) {
        let offset = match list {
          @model.Activity => self.state.scroll_activity.offset().y()
          @model.Items => self.state.scroll_list.offset().y()
        }
        let local_y = point.y() - value.viewport.top() + offset
        let index = (local_y / value.row_height).floor().to_int()
        self.state.select(list, index)
      }
  }
}

///|
fn DemoSession::handle_scroll(
  self : DemoSession,
  point : @primitives.Point,
  delta : @primitives.Point,
) -> DemoBoolResult {
  if self.palette.is_open() {
    return Ok(false)
  }
  let factor = if delta.y().abs() <= 3.0 { 24.0 } else { 1.0 }
  let dy = -delta.y() * factor
  let mut handled = false
  match self.layout.activity {
    Some(region) =>
      if region.viewport.contains(point) {
        self.state.scroll_by(@model.Activity, -delta.x(), dy)
        handled = true
      }
    None => ()
  }
  match self.layout.list {
    Some(region) =>
      if region.viewport.contains(point) {
        self.state.scroll_by(@model.Items, -delta.x(), dy)
        handled = true
      }
    None => ()
  }
  Ok(handled)
}

///|
fn DemoSession::apply_cursor(
  self : DemoSession,
  point : @primitives.Point,
) -> DemoUnitResult {
  let cursor = if self.palette.is_open() &&
    self.layout.palette.field.contains(point) {
    @platform.Text
  } else if self.layout.note_field is Some(region) &&
    region.bounds.contains(point) {
    @platform.Text
  } else {
    match self.hovered {
      Some(id) =>
        if demo_button_kind(id) is Some(_) ||
          demo_list_kind(id) is Some(_) ||
          (id >= 100UL && id < 104UL) {
          @platform.PointingHand
        } else {
          @platform.Arrow
        }
      None => @platform.Arrow
    }
  }
  match (self.platform.host.set_cursor)(cursor) {
    Err(error) => {
      self.state.set_status("Cursor error: " + error.code().label())
      Ok(())
    }
    Ok(_) => Ok(())
  }
}
