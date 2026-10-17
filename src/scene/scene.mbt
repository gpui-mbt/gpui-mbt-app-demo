///|
/// Copied logical text metrics supplied by the platform adapter.
pub(all) struct SceneTextMetrics {
  width : Double
  line_height : Double
}

///|
pub fn SceneTextMetrics::new(
  width : Double,
  line_height : Double,
) -> SceneTextMetrics {
  { width, line_height, }
}

///|
/// Platform-neutral inputs for one demo frame. Platform entry points own the
/// host/event loop and supply text measurement; this package owns composition.
pub(all) struct SceneInputs {
  state : @model.DemoState
  layout : @model.UiLayout
  buttons : Array[@button.Button]
  note : @text_field.TextField
  palette : @command_palette.CommandPalette
  tree : @element.ElementTree
  hovered : UInt64?
  pointer : @primitives.Point?
  measure : (String, Double) -> SceneTextMetrics
  platform_label : String
}

///|
pub fn SceneInputs::new(
  state : @model.DemoState,
  layout : @model.UiLayout,
  buttons : Array[@button.Button],
  note : @text_field.TextField,
  palette : @command_palette.CommandPalette,
  tree : @element.ElementTree,
  hovered : UInt64?,
  pointer : @primitives.Point?,
  measure : (String, Double) -> SceneTextMetrics,
  platform_label : String,
) -> SceneInputs {
  {
    state,
    layout,
    buttons,
    note,
    palette,
    tree,
    hovered,
    pointer,
    measure,
    platform_label,
  }
}

///|
fn SceneInputs::button(
  self : SceneInputs,
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
fn scene_list_kind(id : UInt64) -> @model.ListKind? {
  match id {
    401UL => Some(@model.Activity)
    402UL => Some(@model.Items)
    _ => None
  }
}

///|
fn scene_quad(
  builder : @gpui_scene.SceneBuilder,
  bounds : @primitives.Rect,
  color : @primitives.Color,
) -> Unit {
  match builder.quad(bounds, color) {
    Err(_) => ()
    Ok(_) => ()
  }
}

///|
fn scene_inset(bounds : @primitives.Rect, amount : Double) -> @primitives.Rect {
  @primitives.Rect::new(
    bounds.left() + amount,
    bounds.top() + amount,
    bounds.size().width() - amount * 2.0,
    bounds.size().height() - amount * 2.0,
  ).unwrap()
}

///|
fn SceneInputs::scene_label(
  self : SceneInputs,
  builder : @gpui_scene.SceneBuilder,
  bounds : @primitives.Rect,
  text : String,
  size : Double,
  color : @primitives.Color,
  align : @gpui_scene.TextAlign,
  vertical : @gpui_scene.TextVerticalAlign,
  clip : Int32?,
) -> Unit {
  let measure = self.measure
  let metrics = measure(text, size)
  match
    builder.text(
      bounds,
      text,
      size,
      color,
      align,
      vertical,
      metrics.width,
      metrics.line_height,
      clip,
    ) {
    Err(_) => ()
    Ok(_) => ()
  }
}

///|
fn scene_field_palette(
  theme : @model.ThemeColors,
) -> @text_field.TextFieldPaintPalette {
  @text_field.TextFieldPaintPalette::new(
    theme.field_bg,
    theme.field_border,
    theme.accent,
    theme.field_text,
    theme.field_selection,
    theme.field_selection,
    theme.field_caret,
  )
}

///|
fn SceneInputs::scene_field(
  self : SceneInputs,
  builder : @gpui_scene.SceneBuilder,
  field : @text_field.TextField,
  theme : @model.ThemeColors,
) -> Unit {
  ignore(self)
  let base = match builder.reserve_ids(8) {
    Err(_) => return
    Ok(value) => value
  }
  let clip = match builder.clip([field.content_bounds()]) {
    Err(_) => return
    Ok(value) => value
  }
  let (_, items) = match
    field.paint_items_with_palette(base, clip, scene_field_palette(theme)) {
    Err(_) => return
    Ok(value) => value
  }
  match builder.push_items(items) {
    Err(_) => ()
    Ok(_) => ()
  }
}

///|
fn SceneInputs::scene_button(
  self : SceneInputs,
  builder : @gpui_scene.SceneBuilder,
  button : @button.Button,
  theme : @model.ThemeColors,
) -> Unit {
  let bounds = button.bounds()
  let kind = match @model.ButtonKind::from_id(button.id()) {
    Some(value) => value
    None => return
  }
  let primary = kind == @model.Increment || kind == @model.Copy
  let focused = button.is_focused()
  let fill = if !button.is_enabled() {
    theme.button_disabled
  } else if button.is_loading() {
    theme.card_alt
  } else if button.is_pressed() {
    theme.button_pressed
  } else if button.is_hovered() {
    theme.button_hover
  } else if primary {
    theme.accent
  } else if kind == @model.OpenPalette || kind == @model.OpenPaletteCard {
    theme.accent_soft
  } else {
    theme.button_fill
  }
  let border = if focused {
    theme.focus_ring
  } else if primary {
    theme.accent
  } else {
    theme.card_border
  }
  let text = if !button.is_enabled() {
    theme.disabled_text
  } else if primary {
    theme.accent_text
  } else {
    theme.text
  }
  scene_quad(builder, bounds, border)
  let inset = if focused { 2.0 } else { 1.0 }
  let inner = scene_inset(bounds, inset)
  scene_quad(builder, inner, fill)
  if button.is_loading() {
    let bar = @primitives.Rect::new(
      inner.left(),
      inner.bottom() - 3.0,
      inner.size().width(),
      3.0,
    ).unwrap()
    scene_quad(builder, bar, theme.accent)
  }
  self.scene_label(
    builder,
    scene_inset(inner, 6.0),
    button.label(),
    14.0,
    text,
    @gpui_scene.TextAlign::Center,
    @gpui_scene.TextVerticalAlign::Center,
    None,
  )
}

///|
fn SceneInputs::scene_nav(
  self : SceneInputs,
  builder : @gpui_scene.SceneBuilder,
  region : @model.WidgetRegion,
  page : @model.Page,
  theme : @model.ThemeColors,
  wide : Bool,
) -> Unit {
  let selected = self.state.page == page
  let hovered = self.hovered == Some(region.id)
  let focused = self.tree.is_focused(region.id)
  let fill = if selected {
    theme.accent_soft
  } else if hovered {
    theme.card_alt
  } else {
    theme.sidebar_bg
  }
  scene_quad(builder, region.bounds, fill)
  if selected {
    let accent_bar = @primitives.Rect::new(
      region.bounds.left(),
      region.bounds.top() + 6.0,
      3.0,
      region.bounds.size().height() - 12.0,
    ).unwrap()
    scene_quad(builder, accent_bar, theme.accent)
  }
  if focused {
    match builder.border(region.bounds, 1.0, theme.focus_ring) {
      Err(_) => ()
      Ok(_) => ()
    }
  }
  let label = if wide { page.label() } else { page.short_label() }
  self.scene_label(
    builder,
    scene_inset(region.bounds, 12.0),
    label,
    14.0,
    if selected {
      theme.text
    } else {
      theme.muted
    },
    @gpui_scene.TextAlign::Left,
    @gpui_scene.TextVerticalAlign::Center,
    None,
  )
}

///|
fn scene_scrollbar(
  builder : @gpui_scene.SceneBuilder,
  viewport : @primitives.Rect,
  content_height : Double,
  offset : Double,
  theme : @model.ThemeColors,
) -> Unit {
  if content_height <= viewport.size().height() + 1.0 {
    return
  }
  let track = @primitives.Rect::new(
    viewport.right() - 4.0,
    viewport.top() + 2.0,
    3.0,
    viewport.size().height() - 4.0,
  ).unwrap()
  scene_quad(builder, track, theme.card_alt)
  let max_offset = content_height - viewport.size().height()
  let clamped = if offset < 0.0 {
    0.0
  } else if offset > max_offset {
    max_offset
  } else {
    offset
  }
  let ratio = if max_offset <= 0.0 { 0.0 } else { clamped / max_offset }
  let mut thumb_height = viewport.size().height() *
    viewport.size().height() /
    content_height
  if thumb_height < 18.0 {
    thumb_height = 18.0
  }
  let thumb_top = viewport.top() +
    2.0 +
    (viewport.size().height() - 4.0 - thumb_height) * ratio
  let thumb = @primitives.Rect::new(
    viewport.right() - 4.0,
    thumb_top,
    3.0,
    thumb_height,
  ).unwrap()
  scene_quad(builder, thumb, theme.scrollbar)
}

///|
fn SceneInputs::scene_list(
  self : SceneInputs,
  builder : @gpui_scene.SceneBuilder,
  region : @model.ListRegion,
  count : Int32,
  offset : Double,
  selected : Int32?,
  theme : @model.ThemeColors,
  activity : Bool,
) -> Unit {
  let clip = match builder.clip([region.viewport]) {
    Err(_) => return
    Ok(value) => value
  }
  let hovered_index = match self.pointer {
    Some(point) =>
      if region.viewport.contains(point) {
        let local_y = point.y() - region.viewport.top() + offset
        Some((local_y / region.row_height).floor().to_int())
      } else {
        None
      }
    None => None
  }
  let visible = (region.viewport.size().height() / region.row_height)
    .ceil()
    .to_int() +
    1
  let first = if offset <= 0.0 {
    0
  } else {
    (offset / region.row_height).floor().to_int()
  }
  let mut index = first
  while index < count && index < first + visible {
    let y = region.viewport.top() +
      index.to_double() * region.row_height -
      offset
    if y + region.row_height >= region.viewport.top() &&
      y <= region.viewport.bottom() {
      let row = @primitives.Rect::new(
        region.viewport.left(),
        y,
        region.viewport.size().width(),
        region.row_height,
      ).unwrap()
      let is_selected = selected == Some(index)
      let is_hovered = hovered_index == Some(index)
      if is_selected {
        scene_quad(builder, row, theme.selected_row)
      } else if is_hovered {
        scene_quad(builder, row, theme.card_alt)
      }
      let label = if activity {
        if index < self.state.activity.length() {
          self.state.activity[index]
        } else {
          ""
        }
      } else {
        self.state.list_item(index)
      }
      let label_text = if activity { "\{index + 1}. \{label}" } else { label }
      self.scene_label(
        builder,
        @primitives.Rect::new(
          row.left() + 12.0,
          row.top() + 2.0,
          row.size().width() - 24.0,
          row.size().height() - 4.0,
        ).unwrap(),
        label_text,
        13.0,
        if is_selected {
          theme.text
        } else {
          theme.muted
        },
        @gpui_scene.TextAlign::Left,
        @gpui_scene.TextVerticalAlign::Center,
        Some(clip),
      )
    }
    index += 1
  }
  scene_scrollbar(
    builder,
    region.viewport,
    region.content_height,
    offset,
    theme,
  )
}

///|
fn SceneInputs::scene_stats(
  self : SceneInputs,
  builder : @gpui_scene.SceneBuilder,
  layout : @model.UiLayout,
  theme : @model.ThemeColors,
) -> Unit {
  let values = [
    ("Clicks", self.state.clicks.to_string()),
    ("Palette actions", self.state.palette_actions.to_string()),
    ("Note chars", self.state.note_len().to_string()),
  ]
  for index in 0..<layout.cards.length() {
    if index >= 3 {
      break
    }
    let card = layout.cards[index]
    scene_quad(builder, card, theme.card_border)
    scene_quad(builder, scene_inset(card, 1.0), theme.card_bg)
    let (label, value) = values[index]
    self.scene_label(
      builder,
      @primitives.Rect::new(
        card.left() + 18.0,
        card.top() + 14.0,
        card.size().width() - 36.0,
        18.0,
      ).unwrap(),
      label,
      12.0,
      theme.muted,
      @gpui_scene.TextAlign::Left,
      @gpui_scene.TextVerticalAlign::Top,
      None,
    )
    self.scene_label(
      builder,
      @primitives.Rect::new(
        card.left() + 18.0,
        card.top() + 40.0,
        card.size().width() - 36.0,
        38.0,
      ).unwrap(),
      value,
      28.0,
      theme.accent,
      @gpui_scene.TextAlign::Left,
      @gpui_scene.TextVerticalAlign::Top,
      None,
    )
  }
}

///|
fn SceneInputs::scene_buttons(
  self : SceneInputs,
  builder : @gpui_scene.SceneBuilder,
  theme : @model.ThemeColors,
) -> Unit {
  for region in self.layout.buttons {
    match @model.ButtonKind::from_id(region.id) {
      Some(kind) =>
        match self.button(kind) {
          Some(button) => self.scene_button(builder, button, theme)
          None => ()
        }
      None => ()
    }
  }
}

///|
fn SceneInputs::scene_palette(
  self : SceneInputs,
  builder : @gpui_scene.SceneBuilder,
  theme : @model.ThemeColors,
) -> Unit {
  let palette = self.layout.palette
  scene_quad(builder, palette.overlay, theme.overlay)
  let shadow = @primitives.Rect::new(
    palette.panel.left() + 5.0,
    palette.panel.top() + 5.0,
    palette.panel.size().width(),
    palette.panel.size().height(),
  ).unwrap()
  scene_quad(builder, shadow, theme.window_bg)
  scene_quad(builder, palette.panel, theme.panel_border)
  scene_quad(builder, scene_inset(palette.panel, 1.0), theme.panel_bg)
  self.scene_label(
    builder,
    palette.title,
    "Command palette",
    20.0,
    theme.text,
    @gpui_scene.TextAlign::Left,
    @gpui_scene.TextVerticalAlign::Top,
    None,
  )
  self.scene_label(
    builder,
    @primitives.Rect::new(
      palette.title.left(),
      palette.title.top() + 28.0,
      palette.title.size().width(),
      16.0,
    ).unwrap(),
    "Type to filter · Up/Down select · Enter run · Esc close",
    11.0,
    theme.muted,
    @gpui_scene.TextAlign::Left,
    @gpui_scene.TextVerticalAlign::Top,
    None,
  )
  self.scene_field(builder, self.palette.field(), theme)
  let picker = self.palette.picker()
  let visible = picker.visible_commands()
  let active = picker.active_command()
  let clip = match builder.clip([palette.list]) {
    Err(_) => return
    Ok(value) => value
  }
  if visible.length() == 0 {
    self.scene_label(
      builder,
      @primitives.Rect::new(
        palette.list.left() + 8.0,
        palette.list.top() + 6.0,
        palette.list.size().width() - 16.0,
        24.0,
      ).unwrap(),
      "no matching commands",
      13.0,
      theme.muted,
      @gpui_scene.TextAlign::Left,
      @gpui_scene.TextVerticalAlign::Top,
      Some(clip),
    )
  } else {
    for index in 0..<visible.length() {
      if index >= palette.rows.length() {
        break
      }
      let row = palette.rows[index]
      let command = visible[index]
      let selected = match active {
        Some(value) => value.id() == command.id()
        None => false
      }
      if selected {
        scene_quad(builder, row, theme.accent_soft)
      }
      self.scene_label(
        builder,
        @primitives.Rect::new(
          row.left() + 10.0,
          row.top() + 2.0,
          row.size().width() - 20.0,
          row.size().height() - 4.0,
        ).unwrap(),
        command.label(),
        13.0,
        if !command.is_enabled() {
          theme.faint
        } else if selected {
          theme.text
        } else {
          theme.muted
        },
        @gpui_scene.TextAlign::Left,
        @gpui_scene.TextVerticalAlign::Center,
        Some(clip),
      )
    }
  }
  self.scene_label(
    builder,
    palette.footer,
    "\{picker.match_count()} commands  ·  Enter run  ·  Esc close  ·  Cmd/Ctrl+K opens",
    11.0,
    theme.faint,
    @gpui_scene.TextAlign::Left,
    @gpui_scene.TextVerticalAlign::Top,
    None,
  )
}

///|
fn SceneInputs::scene_status(
  self : SceneInputs,
  builder : @gpui_scene.SceneBuilder,
  theme : @model.ThemeColors,
) -> Unit {
  let focus = match self.tree.focused() {
    Some(@model.NOTE_FIELD_ID) => "Note field"
    Some(@model.PALETTE_FIELD_ID) => "Palette field"
    Some(id) =>
      match @model.ButtonKind::from_id(id) {
        Some(kind) => kind.label()
        None =>
          match scene_list_kind(id) {
            Some(_) => "List"
            None => "Navigation"
          }
      }
    None => "None"
  }
  let hover = match self.hovered {
    Some(id) =>
      match @model.ButtonKind::from_id(id) {
        Some(kind) => kind.label()
        None => "row"
      }
    None => "None"
  }
  self.scene_label(
    builder,
    self.layout.status,
    "Focus: \{focus}   Hover: \{hover}   Accent: \{self.state.accent.label()}  ·  \{self.state.status}",
    11.0,
    theme.faint,
    @gpui_scene.TextAlign::Left,
    @gpui_scene.TextVerticalAlign::Top,
    None,
  )
}

///|
/// Compose the complete demo frame. The caller samples the viewport and
/// backing scale; platform-specific text measurement is supplied through
/// `SceneInputs.measure`.
pub fn SceneInputs::build_scene(
  self : SceneInputs,
  viewport : @primitives.Rect,
  scale : Double,
) -> Result[@gpui_scene.SceneSnapshot, @gpui_scene.SceneBuilderError] {
  let builder = match @gpui_scene.SceneBuilder::new(viewport, scale) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let theme = @model.ThemeColors::for_accent(self.state.accent)
  scene_quad(builder, viewport, theme.window_bg)
  scene_quad(builder, self.layout.sidebar, theme.sidebar_bg)
  scene_quad(
    builder,
    @primitives.Rect::new(
      self.layout.sidebar.right() - 1.0,
      0.0,
      1.0,
      viewport.size().height(),
    ).unwrap(),
    theme.sidebar_border,
  )
  let wide = self.layout.sidebar.size().width() >= @model.SIDEBAR_WIDE
  self.scene_label(
    builder,
    @primitives.Rect::new(24.0, 28.0, 180.0, 30.0).unwrap(),
    if wide {
      "gpui.mbt"
    } else {
      "g"
    },
    22.0,
    theme.accent,
    @gpui_scene.TextAlign::Left,
    @gpui_scene.TextVerticalAlign::Top,
    None,
  )
  if wide {
    self.scene_label(
      builder,
      @primitives.Rect::new(24.0, 60.0, 190.0, 18.0).unwrap(),
      self.platform_label + " demo",
      11.0,
      theme.muted,
      @gpui_scene.TextAlign::Left,
      @gpui_scene.TextVerticalAlign::Top,
      None,
    )
  }
  for index in 0..<self.layout.nav.length() {
    let page = @model.Page::from_index(index).unwrap()
    self.scene_nav(builder, self.layout.nav[index], page, theme, wide)
  }
  self.scene_label(
    builder,
    @primitives.Rect::new(20.0, viewport.size().height() - 62.0, 190.0, 18.0).unwrap(),
    self.platform_label,
    11.0,
    theme.faint,
    @gpui_scene.TextAlign::Left,
    @gpui_scene.TextVerticalAlign::Top,
    None,
  )
  self.scene_label(
    builder,
    @primitives.Rect::new(20.0, viewport.size().height() - 44.0, 190.0, 18.0).unwrap(),
    "Scene v1",
    11.0,
    theme.faint,
    @gpui_scene.TextAlign::Left,
    @gpui_scene.TextVerticalAlign::Top,
    None,
  )
  self.scene_label(
    builder,
    @primitives.Rect::new(
      self.layout.header.left(),
      self.layout.header.top(),
      self.layout.header.size().width() - 170.0,
      34.0,
    ).unwrap(),
    self.state.page.label(),
    26.0,
    theme.text,
    @gpui_scene.TextAlign::Left,
    @gpui_scene.TextVerticalAlign::Top,
    None,
  )
  self.scene_label(
    builder,
    @primitives.Rect::new(
      self.layout.header.left(),
      self.layout.header.top() + 38.0,
      self.layout.header.size().width() - 170.0,
      18.0,
    ).unwrap(),
    self.state.page.subtitle(),
    12.0,
    theme.muted,
    @gpui_scene.TextAlign::Left,
    @gpui_scene.TextVerticalAlign::Top,
    None,
  )
  match self.button(@model.OpenPalette) {
    Some(button) => self.scene_button(builder, button, theme)
    None => ()
  }
  match self.state.page {
    @model.Overview => {
      self.scene_stats(builder, self.layout, theme)
      self.scene_buttons(builder, theme)
      let note_card = self.layout.cards[3]
      scene_quad(builder, note_card, theme.card_border)
      scene_quad(builder, scene_inset(note_card, 1.0), theme.card_bg)
      self.scene_label(
        builder,
        @primitives.Rect::new(
          note_card.left() + 18.0,
          note_card.top() + 14.0,
          note_card.size().width() - 36.0,
          20.0,
        ).unwrap(),
        "Scratch note",
        14.0,
        theme.text,
        @gpui_scene.TextAlign::Left,
        @gpui_scene.TextVerticalAlign::Top,
        None,
      )
      self.scene_label(
        builder,
        @primitives.Rect::new(
          note_card.left() + 18.0,
          note_card.top() + 34.0,
          note_card.size().width() - 36.0,
          16.0,
        ).unwrap(),
        "Type text, Enter commits",
        11.0,
        theme.faint,
        @gpui_scene.TextAlign::Left,
        @gpui_scene.TextVerticalAlign::Top,
        None,
      )
      self.scene_field(builder, self.note, theme)
      let activity_card = self.layout.cards[4]
      scene_quad(builder, activity_card, theme.card_border)
      scene_quad(builder, scene_inset(activity_card, 1.0), theme.card_bg)
      self.scene_label(
        builder,
        @primitives.Rect::new(
          activity_card.left() + 18.0,
          activity_card.top() + 14.0,
          activity_card.size().width() - 36.0,
          20.0,
        ).unwrap(),
        "Recent activity",
        14.0,
        theme.text,
        @gpui_scene.TextAlign::Left,
        @gpui_scene.TextVerticalAlign::Top,
        None,
      )
      match self.layout.activity {
        Some(region) =>
          self.scene_list(
            builder,
            region,
            self.state.activity_count(),
            self.state.scroll_activity.offset().y(),
            self.state.activity_selected,
            theme,
            true,
          )
        None => ()
      }
    }
    @model.Controls => {
      let titles = [
        "Button states", "Scratch note", "Command palette", "Focus and input",
      ]
      for index in 0..<self.layout.cards.length() {
        let card = self.layout.cards[index]
        scene_quad(builder, card, theme.card_border)
        scene_quad(builder, scene_inset(card, 1.0), theme.card_bg)
        self.scene_label(
          builder,
          @primitives.Rect::new(
            card.left() + 18.0,
            card.top() + 14.0,
            card.size().width() - 36.0,
            20.0,
          ).unwrap(),
          titles[index],
          14.0,
          theme.text,
          @gpui_scene.TextAlign::Left,
          @gpui_scene.TextVerticalAlign::Top,
          None,
        )
      }
      self.scene_buttons(builder, theme)
      self.scene_field(builder, self.note, theme)
      let note_card = self.layout.cards[1]
      self.scene_label(
        builder,
        @primitives.Rect::new(
          note_card.left() + 18.0,
          note_card.top() + 38.0,
          note_card.size().width() - 36.0,
          20.0,
        ).unwrap(),
        "\{self.state.note_len()} chars · Shift+Tab moves focus",
        11.0,
        theme.faint,
        @gpui_scene.TextAlign::Left,
        @gpui_scene.TextVerticalAlign::Top,
        None,
      )
      let palette_card = self.layout.cards[2]
      self.scene_label(
        builder,
        @primitives.Rect::new(
          palette_card.left() + 18.0,
          palette_card.top() + 42.0,
          palette_card.size().width() - 36.0,
          40.0,
        ).unwrap(),
        "Eleven typed capabilities, one shared picker.",
        11.0,
        theme.faint,
        @gpui_scene.TextAlign::Left,
        @gpui_scene.TextVerticalAlign::Top,
        None,
      )
      for index in 0..<self.layout.swatches.length() {
        let swatch = self.layout.swatches[index]
        let accent = match index {
          0 => @model.Teal
          1 => @model.Violet
          _ => @model.Amber
        }
        let (red, green, blue) = accent.rgb()
        let color = @primitives.Color::rgba(red, green, blue, 255).unwrap()
        scene_quad(builder, swatch, color)
        if self.state.accent == accent {
          scene_quad(builder, scene_inset(swatch, -3.0), theme.text)
          scene_quad(builder, swatch, color)
        }
      }
      if self.layout.cards.length() >= 4 {
        let focus_card = self.layout.cards[3]
        let lines = [
          "Tab / Shift+Tab  focus traversal", "Enter / Space    activate", "Cmd/Ctrl+K       command palette",
          "Cmd/Ctrl+1..4    jump to page", "Wheel / arrows   scroll lists",
        ]
        for index in 0..<lines.length() {
          self.scene_label(
            builder,
            @primitives.Rect::new(
              focus_card.left() + 18.0,
              focus_card.top() + 46.0 + index.to_double() * 24.0,
              focus_card.size().width() - 36.0,
              20.0,
            ).unwrap(),
            lines[index],
            12.0,
            theme.muted,
            @gpui_scene.TextAlign::Left,
            @gpui_scene.TextVerticalAlign::Top,
            None,
          )
        }
      }
    }
    @model.Lists => {
      let card = self.layout.cards[0]
      scene_quad(builder, card, theme.card_border)
      scene_quad(builder, scene_inset(card, 1.0), theme.card_bg)
      self.scene_label(
        builder,
        @primitives.Rect::new(
          card.left() + 18.0,
          card.top() + 14.0,
          card.size().width() - 36.0,
          20.0,
        ).unwrap(),
        "Scrollable list",
        14.0,
        theme.text,
        @gpui_scene.TextAlign::Left,
        @gpui_scene.TextVerticalAlign::Top,
        None,
      )
      self.scene_label(
        builder,
        @primitives.Rect::new(
          card.left() + 18.0,
          card.top() + 34.0,
          card.size().width() - 36.0,
          16.0,
        ).unwrap(),
        "Wheel, arrows, PageUp/PageDown, Home/End",
        11.0,
        theme.faint,
        @gpui_scene.TextAlign::Left,
        @gpui_scene.TextVerticalAlign::Top,
        None,
      )
      match self.layout.list {
        Some(region) =>
          self.scene_list(
            builder,
            region,
            @model.LIST_ROWS,
            self.state.scroll_list.offset().y(),
            self.state.list_selected,
            theme,
            false,
          )
        None => ()
      }
    }
    @model.About => {
      let first = self.layout.cards[0]
      let second = self.layout.cards[1]
      scene_quad(builder, first, theme.card_border)
      scene_quad(builder, scene_inset(first, 1.0), theme.card_bg)
      scene_quad(builder, second, theme.card_border)
      scene_quad(builder, scene_inset(second, 1.0), theme.card_bg)
      self.scene_label(
        builder,
        @primitives.Rect::new(
          first.left() + 20.0,
          first.top() + 16.0,
          first.size().width() - 40.0,
          24.0,
        ).unwrap(),
        "Reusable layers",
        18.0,
        theme.text,
        @gpui_scene.TextAlign::Left,
        @gpui_scene.TextVerticalAlign::Top,
        None,
      )
      let first_lines = [
        "app/            WindowView runtime, bounded ticks, frame checks", "scene/          SceneBuilder IDs, clips, aligned text",
        "platform/macos_app/  CoreText painter, TextField adapter, cursor", "platform/testing/    Frame analysis, scripted backend",
        "controls/       Button, TextField, CommandPalette",
      ]
      for index in 0..<first_lines.length() {
        self.scene_label(
          builder,
          @primitives.Rect::new(
            first.left() + 20.0,
            first.top() + 52.0 + index.to_double() * 28.0,
            first.size().width() - 40.0,
            22.0,
          ).unwrap(),
          first_lines[index],
          12.0,
          theme.muted,
          @gpui_scene.TextAlign::Left,
          @gpui_scene.TextVerticalAlign::Top,
          None,
        )
      }
      self.scene_label(
        builder,
        @primitives.Rect::new(
          second.left() + 20.0,
          second.top() + 16.0,
          second.size().width() - 40.0,
          24.0,
        ).unwrap(),
        "Input and limits",
        18.0,
        theme.text,
        @gpui_scene.TextAlign::Left,
        @gpui_scene.TextVerticalAlign::Top,
        None,
      )
      let second_lines = [
        "ASCII key adapter; no committed IME/text input yet", "App-level command palette; no native menu bar",
        "One Button accessibility binding; no general AX tree", "Legacy scene subset: quads, text, rectangle clips",
        "Demo only; no macOS support tier is claimed",
      ]
      for index in 0..<second_lines.length() {
        self.scene_label(
          builder,
          @primitives.Rect::new(
            second.left() + 20.0,
            second.top() + 52.0 + index.to_double() * 28.0,
            second.size().width() - 40.0,
            22.0,
          ).unwrap(),
          second_lines[index],
          12.0,
          theme.muted,
          @gpui_scene.TextAlign::Left,
          @gpui_scene.TextVerticalAlign::Top,
          None,
        )
      }
    }
  }
  self.scene_status(builder, theme)
  if self.palette.is_open() {
    self.scene_palette(builder, theme)
  }
  builder.snapshot()
}
