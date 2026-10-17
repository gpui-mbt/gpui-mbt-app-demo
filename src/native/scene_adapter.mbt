///|
fn DemoSession::build_scene(
  self : DemoSession,
  metrics : @gpui_app.WindowMetrics,
) -> DemoSceneResult {
  let viewport = match metrics.logical_rect() {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let text_ops = self.platform.text
  let measure = fn(text : String, size : Double) {
    let metrics = (text_ops.measure_text)(text, size)
    @demo_scene.SceneTextMetrics::new(metrics.width, metrics.line_height)
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
    self.platform.backend_label,
  )
  match inputs.build_scene(viewport, self.scale) {
    Err(_) =>
      Err(
        demo_app_error(
          self.platform,
          "scene",
          "SceneBuilder could not compose the demo",
        ),
      )
    Ok(value) => Ok(value)
  }
}
