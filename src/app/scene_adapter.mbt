///|
fn DemoSession::build_scene(
  self : DemoSession,
  metrics : @gpui_app.WindowMetrics,
) -> DemoSceneResult {
  let viewport = match metrics.logical_rect() {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let painter = self.painter
  let measure = fn(text : String, size : Double) {
    match painter.measure(text, size) {
      Ok(value) =>
        @demo_scene.SceneTextMetrics::new(value.width, value.line_height)
      Err(_) =>
        @demo_scene.SceneTextMetrics::new(
          text.length().to_double() * size * 0.55,
          size * 1.25,
        )
    }
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
    "AppKit + Metal",
  )
  match inputs.build_scene(viewport, self.scale) {
    Err(_) =>
      Err(demo_app_error("scene", "SceneBuilder could not compose the demo"))
    Ok(value) => Ok(value)
  }
}
