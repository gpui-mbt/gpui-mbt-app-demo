///|
/// A demo accent palette. The application keeps one dark surface theme and
/// cycles only the accent color, which makes repaint behavior easy to observe.
pub(all) enum Accent {
  Teal
  Violet
  Amber
} derive(Eq)

///|
pub extend Accent with Eq::{not_equal, equal}

///|
pub fn Accent::next(self : Accent) -> Accent {
  match self {
    Teal => Violet
    Violet => Amber
    Amber => Teal
  }
}

///|
pub fn Accent::label(self : Accent) -> String {
  match self {
    Teal => "Teal"
    Violet => "Violet"
    Amber => "Amber"
  }
}

///|
pub fn Accent::rgb(self : Accent) -> (Int32, Int32, Int32) {
  match self {
    Teal => (45, 212, 191)
    Violet => (167, 139, 250)
    Amber => (251, 191, 36)
  }
}

///|
/// Copied colors for one frame. The theme is intentionally flat: the macOS
/// renderer's legacy scene subset supports quads, text and rectangle clips.
pub(all) struct ThemeColors {
  window_bg : @primitives.Color
  sidebar_bg : @primitives.Color
  sidebar_border : @primitives.Color
  card_bg : @primitives.Color
  card_border : @primitives.Color
  card_alt : @primitives.Color
  text : @primitives.Color
  muted : @primitives.Color
  faint : @primitives.Color
  accent : @primitives.Color
  accent_text : @primitives.Color
  accent_soft : @primitives.Color
  field_bg : @primitives.Color
  field_border : @primitives.Color
  field_text : @primitives.Color
  field_selection : @primitives.Color
  field_caret : @primitives.Color
  button_fill : @primitives.Color
  button_hover : @primitives.Color
  button_pressed : @primitives.Color
  button_disabled : @primitives.Color
  disabled_text : @primitives.Color
  focus_ring : @primitives.Color
  overlay : @primitives.Color
  panel_bg : @primitives.Color
  panel_border : @primitives.Color
  selected_row : @primitives.Color
  scrollbar : @primitives.Color
  danger : @primitives.Color
}

///|
fn demo_color(
  red : Int32,
  green : Int32,
  blue : Int32,
  alpha : Int32,
) -> @primitives.Color {
  @primitives.Color::rgba(red, green, blue, alpha).unwrap()
}

///|
pub fn ThemeColors::for_accent(accent : Accent) -> ThemeColors {
  let (accent_red, accent_green, accent_blue) = accent.rgb()
  {
    window_bg: demo_color(12, 14, 18, 255),
    sidebar_bg: demo_color(17, 21, 28, 255),
    sidebar_border: demo_color(35, 43, 55, 255),
    card_bg: demo_color(23, 28, 37, 255),
    card_border: demo_color(40, 50, 66, 255),
    card_alt: demo_color(27, 33, 43, 255),
    text: demo_color(232, 238, 247, 255),
    muted: demo_color(148, 163, 184, 255),
    faint: demo_color(100, 116, 139, 255),
    accent: demo_color(accent_red, accent_green, accent_blue, 255),
    accent_text: demo_color(8, 16, 22, 255),
    accent_soft: demo_color(accent_red, accent_green, accent_blue, 55),
    field_bg: demo_color(11, 15, 21, 255),
    field_border: demo_color(42, 52, 66, 255),
    field_text: demo_color(232, 238, 247, 255),
    field_selection: demo_color(accent_red, accent_green, accent_blue, 80),
    field_caret: demo_color(accent_red, accent_green, accent_blue, 255),
    button_fill: demo_color(33, 41, 54, 255),
    button_hover: demo_color(44, 55, 72, 255),
    button_pressed: demo_color(accent_red, accent_green, accent_blue, 90),
    button_disabled: demo_color(28, 32, 39, 255),
    disabled_text: demo_color(105, 115, 130, 255),
    focus_ring: demo_color(accent_red, accent_green, accent_blue, 255),
    overlay: demo_color(5, 7, 10, 170),
    panel_bg: demo_color(20, 25, 33, 255),
    panel_border: demo_color(48, 60, 78, 255),
    selected_row: demo_color(accent_red, accent_green, accent_blue, 55),
    scrollbar: demo_color(70, 82, 100, 255),
    danger: demo_color(248, 113, 113, 255),
  }
}
