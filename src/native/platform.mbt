///|
/// Platform-independent text measurement result for one scene label.
pub(all) struct DemoTextMetrics {
  width : Double
  line_height : Double
}

///|
pub fn DemoTextMetrics::new(
  width : Double,
  line_height : Double,
) -> DemoTextMetrics {
  { width, line_height, }
}

///|
/// Text operations supplied by a native host adapter (CoreText, DirectWrite,
/// or a portable fallback).
pub(all) struct DemoTextOps {
  measure_text : (String, Double) -> DemoTextMetrics
  measure_document : (@text.TextDocument) -> Result[
    @text_layout.TextMeasurement,
    @text_field.TextFieldError,
  ]
  admit_document : (@text.TextDocument, @text_layout.TextMeasurement) -> Result[
    Unit,
    @text_field.TextFieldError,
  ]
  hit_document : (@text.TextDocument, @primitives.Point) -> Result[
    @text_layout.TextHit,
    @text_field.TextFieldError,
  ]
}

///|
pub fn DemoTextOps::new(
  measure_text : (String, Double) -> DemoTextMetrics,
  measure_document : (@text.TextDocument) -> Result[
    @text_layout.TextMeasurement,
    @text_field.TextFieldError,
  ],
  admit_document : (@text.TextDocument, @text_layout.TextMeasurement) -> Result[
    Unit,
    @text_field.TextFieldError,
  ],
  hit_document : (@text.TextDocument, @primitives.Point) -> Result[
    @text_layout.TextHit,
    @text_field.TextFieldError,
  ],
) -> DemoTextOps {
  { measure_text, measure_document, admit_document, hit_document, }
}

///|
/// Window-scoped host operations. The platform entry owns the concrete host
/// and window; the shared session only sees these callbacks.
pub(all) struct DemoHostOps {
  set_cursor : (@platform.Cursor) -> Result[Unit, @diagnostics.FrameworkError]
  request_close : () -> Result[Unit, @diagnostics.FrameworkError]
  request_exit : () -> Result[Unit, @diagnostics.FrameworkError]
  read_clipboard : () -> Result[String, @diagnostics.FrameworkError]
  write_clipboard : (String) -> Result[Unit, @diagnostics.FrameworkError]
  post_test_key : (@primitives.Key, @primitives.Modifiers) -> Result[
    Unit,
    @diagnostics.FrameworkError,
  ]
  post_test_click : (@primitives.Point) -> Result[
    Unit,
    @diagnostics.FrameworkError,
  ]
  capture_frame : () -> Result[
    @testing.FrameCapture,
    @diagnostics.FrameworkError,
  ]
}

///|
pub fn DemoHostOps::new(
  set_cursor : (@platform.Cursor) -> Result[Unit, @diagnostics.FrameworkError],
  request_close : () -> Result[Unit, @diagnostics.FrameworkError],
  request_exit : () -> Result[Unit, @diagnostics.FrameworkError],
  read_clipboard : () -> Result[String, @diagnostics.FrameworkError],
  write_clipboard : (String) -> Result[Unit, @diagnostics.FrameworkError],
  post_test_key : (@primitives.Key, @primitives.Modifiers) -> Result[
    Unit,
    @diagnostics.FrameworkError,
  ],
  post_test_click : (@primitives.Point) -> Result[
    Unit,
    @diagnostics.FrameworkError,
  ],
  capture_frame : () -> Result[
    @testing.FrameCapture,
    @diagnostics.FrameworkError,
  ],
) -> DemoHostOps {
  {
    set_cursor,
    request_close,
    request_exit,
    read_clipboard,
    write_clipboard,
    post_test_key,
    post_test_click,
    capture_frame,
  }
}

///|
/// Optional accessibility bridge. Windows currently supplies `None`.
pub(all) struct DemoAxOps {
  publish : (Int64, String, @primitives.Rect, Bool, Bool, Bool, Int32) -> Result[
    Int64,
    @diagnostics.FrameworkError,
  ]
  revoke : (Int64) -> Unit
  take_request : () -> Result[Int64?, @diagnostics.FrameworkError]
}

///|
pub fn DemoAxOps::new(
  publish : (Int64, String, @primitives.Rect, Bool, Bool, Bool, Int32) -> Result[
    Int64,
    @diagnostics.FrameworkError,
  ],
  revoke : (Int64) -> Unit,
  take_request : () -> Result[Int64?, @diagnostics.FrameworkError],
) -> DemoAxOps {
  { publish, revoke, take_request, }
}

///|
/// Everything a shared demo session needs from one native platform.
pub(all) struct DemoPlatform {
  backend_label : String
  host : DemoHostOps
  text : DemoTextOps
  ax : DemoAxOps?
}

///|
pub fn DemoPlatform::new(
  backend_label : String,
  host : DemoHostOps,
  text : DemoTextOps,
  ax : DemoAxOps?,
) -> DemoPlatform {
  { backend_label, host, text, ax, }
}
