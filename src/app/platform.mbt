///|
fn app_error(
  operation : String,
  message : String,
) -> @diagnostics.FrameworkError {
  @diagnostics.FrameworkError::new(
    @diagnostics.InvalidInput,
    operation,
    subsystem="gpui-mbt-app-demo",
    backend="appkit-metal",
    message~,
  )
}

///|
pub fn macos_demo_platform(
  host : @macos.Host,
  window : @platform.WindowId,
) -> Result[@native.DemoPlatform, @diagnostics.FrameworkError] {
  let adapter = match @macos_app.MacosTextFieldAdapter::new(16.0) {
    Ok(value) => value
    Err(_) =>
      return Err(app_error("text_adapter", "CoreText rejected the field style"))
  }
  let painter = match @macos_app.MacosTextPainter::new(512) {
    Ok(value) => value
    Err(_) =>
      return Err(app_error("text_painter", "text painter rejected its cache"))
  }
  let cursor = @macos_app.CursorState::new()
  let text_ops = @native.DemoTextOps::new(
    fn(text, size) {
      match painter.measure(text, size) {
        Ok(value) =>
          @native.DemoTextMetrics::new(value.width, value.line_height)
        Err(_) =>
          @native.DemoTextMetrics::new(
            text.length().to_double() * size * 0.55,
            size * 1.25,
          )
      }
    },
    fn(document) { adapter.measure(document) },
    fn(document, measurement) { adapter.admit(document, measurement) },
    fn(document, point) { adapter.hit(document, point) },
  )
  let host_ops = @native.DemoHostOps::new(
    fn(cursor_value) {
      match cursor.apply(host, cursor_value) {
        Ok(_) => Ok(())
        Err(error) => Err(error)
      }
    },
    () => host.request_close(window),
    () => host.request_exit(),
    () => host.read_clipboard(),
    fn(text) { host.write_clipboard(text) },
    fn(key, modifiers) { host.post_test_key(window, key, modifiers) },
    fn(point) { host.post_test_click(window, point) },
    () => @testing.capture_frame(host, window),
  )
  let ax = @native.DemoAxOps::new(
    fn(binding, label, bounds, enabled, loading, focused, clicks) {
      let snapshot = @macos.ButtonAccessibilitySnapshot::new(
        label, bounds, enabled, loading, focused, clicks,
      )
      host.publish_button_accessibility(window, binding, snapshot)
    },
    fn(binding) { ignore(host.revoke_button_accessibility(window, binding)) },
    () => host.take_button_accessibility_request(window),
  )
  Ok(@native.DemoPlatform::new("appkit-metal", host_ops, text_ops, Some(ax)))
}
