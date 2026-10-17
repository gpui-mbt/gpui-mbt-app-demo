///|
type WindowsUnitResult = Result[Unit, @diagnostics.FrameworkError]

///|
fn demo_run(smoke : Bool) -> WindowsUnitResult {
  if smoke && @env.get_env_var("GPUI_NATIVE_E2E") != Some("1") {
    return Err(
      windows_error(
        "smoke", "set GPUI_NATIVE_E2E=1 to enable the window-scoped test hooks",
      ),
    )
  }
  let host = match @gpui_windows.Host::start() {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let result = demo_run_host(host, smoke)
  let stopped = host.stop()
  match result {
    Err(error) => Err(error)
    Ok(_) =>
      match stopped {
        Err(error) => Err(error)
        Ok(_) => Ok(())
      }
  }
}

///|
fn demo_run_host(host : @gpui_windows.Host, smoke : Bool) -> WindowsUnitResult {
  for
    capability in [
      @platform.NativeWindow,
      @platform.QuadFrames,
      @platform.GrayscaleTextFrames,
      @platform.PointerKeyboard,
      @platform.Clipboard,
      @platform.Cursor,
    ] {
    match host.require_capability(capability) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
  }
  let window = match
    host.create_window(1040, 720, "gpui.mbt — Windows app demo") {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let (width, height, scale) = match host.window_metrics(window) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let platform = match windows_demo_platform(host, window) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let session = match
    @native.DemoSession::new(platform, window, width, height, scale) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  session.set_smoke(smoke)
  let outcome = match
    session.run_on(
      host,
      window,
      timeout_ms=16,
      max_ticks=if smoke { Some(3000) } else { None },
      present_on_start=true,
    ) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  if smoke && outcome.reason() == @gpui_app.MaxTicks {
    Err(windows_error("smoke", "smoke flow exceeded its tick bound"))
  } else {
    Ok(())
  }
}

///|
fn main {
  let smoke = @env.args().contains("--smoke")
  match demo_run(smoke) {
    Err(error) =>
      println("demo failed: " + error.operation() + ": " + error.code().label())
    Ok(_) => println("demo exited cleanly")
  }
}
