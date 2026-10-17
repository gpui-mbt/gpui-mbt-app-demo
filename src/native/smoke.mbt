///|
fn smoke_dir() -> String {
  match @env.get_env_var("GPUI_SMOKE_DIR") {
    Some(value) =>
      if value.length() > 0 && value.has_suffix("/") {
        value
      } else {
        value + "/"
      }
    None => "build/smoke/"
  }
}

///|
fn smoke_fail(
  platform : DemoPlatform,
  operation : String,
  message : String,
) -> @diagnostics.FrameworkError {
  demo_app_error(platform, operation, message)
}

///|
fn smoke_pixel(
  frame : @testing.FrameCapture,
  x : Double,
  y : Double,
  color : @primitives.Color,
  tolerance : Int32,
) -> Unit {
  match
    frame.pixel_matches_logical(
      x,
      y,
      color.red(),
      color.green(),
      color.blue(),
      tolerance,
    ) {
    Err(_) => abort("smoke: pixel readback failed")
    Ok(true) => ()
    Ok(false) => abort("smoke: pixel did not match the expected theme color")
  }
}

///|
fn smoke_ink(
  frame : @testing.FrameCapture,
  bounds : @primitives.Rect,
  minimum : Int32,
) -> Unit {
  match frame.ink_count(bounds, 150) {
    Err(_) => abort("smoke: ink readback failed")
    Ok(count) =>
      if count < minimum {
        abort("smoke: expected visible text ink")
      }
  }
}

///|
fn DemoSession::smoke_save(
  self : DemoSession,
  frame : @testing.FrameCapture,
  name : String,
) -> Unit {
  let path = smoke_dir() + name + ".ppm"
  match frame.write_ppm(path) {
    Err(_) => abort("smoke: could not write a frame artifact")
    Ok(_) => self.smoke_shot += 1
  }
}

///|
fn DemoSession::smoke_key(
  self : DemoSession,
  key : @primitives.Key,
  modifiers : @primitives.Modifiers,
) -> Unit {
  match (self.platform.host.post_test_key)(key, modifiers) {
    Err(_) => abort("smoke: synthetic key was rejected")
    Ok(_) => ()
  }
}

///|
fn DemoSession::smoke_text(self : DemoSession, text : String) -> Unit {
  for scalar in text.iter() {
    self.smoke_key(
      @primitives.Character(scalar.to_string()),
      @primitives.Modifiers::none(),
    )
  }
}

///|
fn DemoSession::smoke_click(
  self : DemoSession,
  point : @primitives.Point,
) -> Unit {
  match (self.platform.host.post_test_click)(point) {
    Err(_) => abort("smoke: synthetic click was rejected")
    Ok(_) => ()
  }
}

///|
fn DemoSession::smoke_capture(self : DemoSession) -> @testing.FrameCapture {
  match (self.platform.host.capture_frame)() {
    Err(_) => abort("smoke: frame readback was rejected")
    Ok(value) => value
  }
}

///|
fn DemoSession::smoke_after_present(
  self : DemoSession,
  metrics : @gpui_app.WindowMetrics,
) -> DemoUnitResult {
  ignore(metrics)
  if self.smoke_ticks > 2500 {
    return Err(
      smoke_fail(self.platform, "smoke", "smoke flow exceeded its tick bound"),
    )
  }
  self.smoke_ticks += 1
  let frame = self.smoke_capture()
  let theme = @model.ThemeColors::for_accent(self.state.accent)
  match self.smoke_stage {
    0 => {
      smoke_pixel(
        frame,
        self.layout.content.left() + 4.0,
        8.0,
        theme.window_bg,
        2,
      )
      smoke_pixel(frame, 8.0, self.height - 8.0, theme.sidebar_bg, 2)
      smoke_ink(
        frame,
        @primitives.Rect::new(
          self.layout.header.left(),
          self.layout.header.top(),
          self.layout.header.size().width() - 180.0,
          30.0,
        ).unwrap(),
        8,
      )
      self.smoke_save(frame, "01-overview")
      let region = match self.layout.button(@model.Increment) {
        Some(value) => value
        None =>
          return Err(
            smoke_fail(self.platform, "smoke", "increment button is missing"),
          )
      }
      self.smoke_click(
        @primitives.Point::new(
          region.bounds.left() + region.bounds.size().width() / 2.0,
          region.bounds.top() + region.bounds.size().height() / 2.0,
        ).unwrap(),
      )
      self.smoke_stage = 1
      Ok(())
    }
    1 => {
      if self.state.clicks != 1 {
        return Ok(())
      }
      self.smoke_save(frame, "02-increment")
      let region = match self.layout.note_field {
        Some(value) => value
        None =>
          return Err(
            smoke_fail(self.platform, "smoke", "note field is missing"),
          )
      }
      self.smoke_click(
        @primitives.Point::new(
          region.bounds.left() + region.bounds.size().width() / 2.0,
          region.bounds.top() + region.bounds.size().height() / 2.0,
        ).unwrap(),
      )
      self.smoke_stage = 2
      Ok(())
    }
    2 => {
      if self.tree.focused() != Some(NOTE_FIELD_ID) {
        return Ok(())
      }
      self.smoke_text("hello")
      self.smoke_stage = 3
      Ok(())
    }
    3 => {
      if self.state.note != "hello" {
        return Ok(())
      }
      self.smoke_save(frame, "03-note")
      self.smoke_key(
        @primitives.Character("k"),
        @primitives.Modifiers::new(
          shift=false,
          control=false,
          alt=false,
          meta=true,
        ),
      )
      self.smoke_stage = 4
      Ok(())
    }
    4 => {
      if !self.palette.is_open() {
        return Ok(())
      }
      self.smoke_save(frame, "04-palette")
      self.smoke_text("lists")
      self.smoke_stage = 5
      Ok(())
    }
    5 => {
      if self.palette.picker().query() != "lists" {
        return Ok(())
      }
      self.smoke_save(frame, "05-palette-query")
      self.smoke_key(@primitives.Enter, @primitives.Modifiers::none())
      self.smoke_stage = 6
      Ok(())
    }
    6 => {
      if self.state.page != @model.Lists || self.palette.is_open() {
        return Ok(())
      }
      self.smoke_save(frame, "06-lists")
      let region = match self.layout.list {
        Some(value) => value
        None =>
          return Err(smoke_fail(self.platform, "smoke", "list is missing"))
      }
      self.smoke_click(
        @primitives.Point::new(
          region.viewport.left() + region.viewport.size().width() / 2.0,
          region.viewport.top() + region.viewport.size().height() / 2.0,
        ).unwrap(),
      )
      self.smoke_key(@primitives.ArrowDown, @primitives.Modifiers::none())
      self.smoke_stage = 7
      Ok(())
    }
    7 => {
      if self.state.list_selected is None {
        return Ok(())
      }
      self.smoke_save(frame, "07-list-selected")
      self.smoke_key(
        @primitives.Character("k"),
        @primitives.Modifiers::new(
          shift=false,
          control=false,
          alt=false,
          meta=true,
        ),
      )
      self.smoke_stage = 8
      Ok(())
    }
    8 => {
      if !self.palette.is_open() {
        if self.smoke_ticks > 200 {
          abort("smoke: palette did not reopen, status=" + self.state.status)
        }
        return Ok(())
      }
      self.smoke_text("accent")
      self.smoke_stage = 9
      Ok(())
    }
    9 => {
      if self.palette.picker().query() != "accent" {
        if self.smoke_ticks > 300 {
          self.smoke_save(frame, "09-accent-query")
          abort("smoke: accent query = " + self.palette.picker().query())
        }
        return Ok(())
      }
      self.smoke_key(@primitives.Enter, @primitives.Modifiers::none())
      self.smoke_stage = 10
      Ok(())
    }
    10 => {
      if self.palette.is_open() || self.state.accent != @model.Violet {
        if self.smoke_ticks > 500 {
          let frame = self.smoke_capture()
          self.smoke_save(frame, "10-accent-wait")
          abort(
            "smoke: accent wait open=" +
            self.palette.is_open().to_string() +
            " accent=" +
            self.state.accent.label(),
          )
        }
        return Ok(())
      }
      let violet = @model.ThemeColors::for_accent(@model.Violet)
      let region = match self.layout.nav.get(2) {
        Some(value) => value
        None =>
          return Err(
            smoke_fail(self.platform, "smoke", "lists navigation is missing"),
          )
      }
      smoke_pixel(
        frame,
        region.bounds.left() + 1.0,
        region.bounds.top() + region.bounds.size().height() / 2.0,
        violet.accent,
        4,
      )
      self.smoke_save(frame, "08-accent")
      self.smoke_key(
        @primitives.Character("2"),
        @primitives.Modifiers::new(
          shift=false,
          control=false,
          alt=false,
          meta=true,
        ),
      )
      self.smoke_stage = 11
      Ok(())
    }
    11 => {
      if self.state.page != @model.Controls {
        if self.smoke_ticks > 600 {
          abort("smoke: controls shortcut did not change the page")
        }
        return Ok(())
      }
      self.smoke_save(frame, "09-controls")
      self.smoke_key(
        @primitives.Character("4"),
        @primitives.Modifiers::new(
          shift=false,
          control=false,
          alt=false,
          meta=true,
        ),
      )
      self.smoke_stage = 12
      Ok(())
    }
    12 => {
      if self.state.page != @model.About {
        if self.smoke_ticks > 700 {
          abort("smoke: about shortcut did not change the page")
        }
        return Ok(())
      }
      self.smoke_save(frame, "10-about")
      println(
        "DEMO_SMOKE PASS shots=\{self.smoke_shot} clicks=\{self.state.clicks} note=\{self.state.note} page=\{self.state.page.label()} accent=\{self.state.accent.label()}",
      )
      self.smoke_stage = 13
      match (self.platform.host.request_close)() {
        Err(error) => Err(error)
        Ok(_) => Ok(())
      }
    }
    _ => Ok(())
  }
}

///|
fn DemoSession::smoke_on_idle(self : DemoSession) -> DemoUnitResult {
  self.smoke_ticks += 1
  if self.smoke_stage >= 13 && !self.palette.is_open() {
    self.closing = true
  }
  if self.smoke_stage == 9 &&
    self.palette.picker().query() != "accent" &&
    self.smoke_ticks > 300 {
    let frame = self.smoke_capture()
    self.smoke_save(frame, "09-idle-query")
    abort("smoke: idle query = " + self.palette.picker().query())
  }
  Ok(())
}
