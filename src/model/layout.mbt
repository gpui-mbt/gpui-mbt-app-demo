///|
pub const SIDEBAR_WIDE : Double = 232.0

///|
pub const SIDEBAR_RAIL : Double = 76.0

///|
pub(all) enum ButtonKind {
  Increment
  Reset
  Copy
  CycleAccent
  ToggleLoading
  OpenPalette
  OpenPaletteCard
  Disabled
} derive(Eq)

///|
pub extend ButtonKind with Eq::{not_equal, equal}

///|
pub fn ButtonKind::id(self : ButtonKind) -> UInt64 {
  match self {
    Increment => 201UL
    Reset => 202UL
    Copy => 203UL
    CycleAccent => 204UL
    ToggleLoading => 205UL
    OpenPalette => 206UL
    OpenPaletteCard => 207UL
    Disabled => 208UL
  }
}

///|
pub fn ButtonKind::from_id(id : UInt64) -> ButtonKind? {
  match id {
    201UL => Some(Increment)
    202UL => Some(Reset)
    203UL => Some(Copy)
    204UL => Some(CycleAccent)
    205UL => Some(ToggleLoading)
    206UL => Some(OpenPalette)
    207UL => Some(OpenPaletteCard)
    208UL => Some(Disabled)
    _ => None
  }
}

///|
pub fn ButtonKind::label(self : ButtonKind) -> String {
  match self {
    Increment => "Increment"
    Reset => "Reset"
    Copy => "Copy summary"
    CycleAccent => "Cycle accent"
    ToggleLoading => "Toggle loading"
    OpenPalette => "Cmd/Ctrl+K Palette"
    OpenPaletteCard => "Open palette"
    Disabled => "Disabled"
  }
}

///|
pub(all) enum WidgetKind {
  Nav(Page)
  Button(ButtonKind)
  NoteField
  List(ListKind)
}

///|
pub(all) struct WidgetRegion {
  id : UInt64
  kind : WidgetKind
  bounds : @primitives.Rect
}

///|
pub fn WidgetRegion::focusable(self : WidgetRegion) -> Bool {
  match self.kind {
    Button(Disabled) => false
    _ => true
  }
}

///|
pub(all) struct ListRegion {
  kind : ListKind
  id : UInt64
  viewport : @primitives.Rect
  content_height : Double
  row_height : Double
  first_index : Int32
}

///|
pub(all) struct PaletteRegion {
  overlay : @primitives.Rect
  panel : @primitives.Rect
  title : @primitives.Rect
  field : @primitives.Rect
  list : @primitives.Rect
  footer : @primitives.Rect
  rows : Array[@primitives.Rect]
}

///|
pub(all) struct UiLayout {
  viewport : @primitives.Rect
  sidebar : @primitives.Rect
  header : @primitives.Rect
  content : @primitives.Rect
  status : @primitives.Rect
  nav : Array[WidgetRegion]
  palette_button : WidgetRegion
  buttons : Array[WidgetRegion]
  note_field : WidgetRegion?
  activity : ListRegion?
  list : ListRegion?
  palette : PaletteRegion
  cards : Array[@primitives.Rect]
  swatches : Array[@primitives.Rect]
  page : Page
}

///|
pub fn UiLayout::widgets(self : UiLayout) -> Array[WidgetRegion] {
  let result = self.nav.copy()
  result.push(self.palette_button)
  for button in self.buttons {
    result.push(button)
  }
  match self.note_field {
    Some(value) => result.push(value)
    None => ()
  }
  match self.activity {
    Some(value) =>
      result.push({
        id: value.id,
        kind: List(Activity),
        bounds: value.viewport,
      })
    None => ()
  }
  match self.list {
    Some(value) =>
      result.push({ id: value.id, kind: List(Items), bounds: value.viewport, })
    None => ()
  }
  result
}

///|
pub fn UiLayout::button(self : UiLayout, kind : ButtonKind) -> WidgetRegion? {
  for button in self.buttons {
    if button.kind is Button(actual) && actual == kind {
      return Some(button)
    }
  }
  if self.palette_button.kind is Button(actual) && actual == kind {
    return Some(self.palette_button)
  }
  None
}

///|
fn lrect(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @primitives.Rect {
  @primitives.Rect::new(x, y, width, height).unwrap()
}

///|
fn lsize(width : Double, height : Double) -> @primitives.Size {
  @primitives.Size::new(width, height).unwrap()
}

///|
fn lpoints(value : Double) -> @layout.Dimension {
  match @layout.Dimension::points(value) {
    Ok(value) => value
    Err(_) => @layout.Dimension::auto()
  }
}

///|
fn ltranslate(
  rect : @primitives.Rect,
  x : Double,
  y : Double,
) -> @primitives.Rect {
  rect.translated(@primitives.Point::new(x, y).unwrap()).unwrap()
}

///|
fn lregion(
  id : UInt64,
  kind : WidgetKind,
  bounds : @primitives.Rect,
) -> WidgetRegion {
  { id, kind, bounds, }
}

///|
fn flex_column(
  origin_x : Double,
  origin_y : Double,
  width : Double,
  heights : Array[Double],
  gap : Double,
) -> Array[@primitives.Rect] {
  let total = heights.fold(init=0.0, (sum, value) => sum + value) +
    gap * (heights.length() - 1).to_double()
  let base = @layout.FlexContainer::new(
    @layout.FlowDirection::column(),
    lsize(width, total),
  )
  let container = match base.with_gap_y(gap) {
    Err(_) => base
    Ok(gapped) => gapped
  }
  let items : Array[@layout.FlexItem] = []
  for index in 0..<heights.length() {
    let height = heights[index]
    let item = @layout.FlexItem::new(
      index.to_uint64() + 1UL,
      lpoints(height),
      lpoints(width),
      lsize(width, height),
    )
    items.push(item)
  }
  match @layout.layout_flex(container, items) {
    Err(_) => manual_column(origin_x, origin_y, width, heights, gap)
    Ok(layout) =>
      layout.items().map(box => ltranslate(box.bounds(), origin_x, origin_y))
  }
}

///|
fn manual_column(
  origin_x : Double,
  origin_y : Double,
  width : Double,
  heights : Array[Double],
  gap : Double,
) -> Array[@primitives.Rect] {
  let result : Array[@primitives.Rect] = []
  let mut y = origin_y
  for height in heights {
    result.push(lrect(origin_x, y, width, height))
    y += height + gap
  }
  result
}

///|
fn flex_row(
  origin_x : Double,
  origin_y : Double,
  width : Double,
  height : Double,
  count : Int32,
  gap : Double,
) -> Array[@primitives.Rect] {
  if count <= 0 {
    return []
  }
  let base = @layout.FlexContainer::new(
    @layout.FlowDirection::row(),
    lsize(width, height),
  )
  let container = match base.with_gap(gap) {
    Err(_) => base
    Ok(gapped) => gapped
  }
  let items : Array[@layout.FlexItem] = []
  for index in 0..<count {
    let item = match
      @layout.FlexItem::new(
        index.to_uint64() + 1UL,
        lpoints(0.0),
        lpoints(height),
        lsize(0.0, height),
      ).with_flex(1.0, 1.0) {
      Err(_) => return manual_row(origin_x, origin_y, width, height, count, gap)
      Ok(value) => value
    }
    items.push(item)
  }
  match @layout.layout_flex(container, items) {
    Err(_) => manual_row(origin_x, origin_y, width, height, count, gap)
    Ok(layout) =>
      layout.items().map(box => ltranslate(box.bounds(), origin_x, origin_y))
  }
}

///|
fn manual_row(
  origin_x : Double,
  origin_y : Double,
  width : Double,
  height : Double,
  count : Int32,
  gap : Double,
) -> Array[@primitives.Rect] {
  let result : Array[@primitives.Rect] = []
  if count <= 0 {
    return result
  }
  let item_width = (width - gap * (count - 1).to_double()) / count.to_double()
  let mut x = origin_x
  for _ in 0..<count {
    result.push(lrect(x, origin_y, item_width, height))
    x += item_width + gap
  }
  result
}

///|
fn place_buttons(
  origin_x : Double,
  origin_y : Double,
  max_width : Double,
  entries : Array[(ButtonKind, Double)],
  gap : Double,
  height : Double,
) -> Array[WidgetRegion] {
  let result : Array[WidgetRegion] = []
  let mut x = origin_x
  let mut y = origin_y
  for entry in entries {
    let (kind, width) = entry
    if x > origin_x && x + width > origin_x + max_width {
      x = origin_x
      y += height + 10.0
    }
    result.push(lregion(kind.id(), Button(kind), lrect(x, y, width, height)))
    x += width + gap
  }
  result
}

///|
fn layout_region_for_list(
  kind : ListKind,
  id : UInt64,
  viewport : @primitives.Rect,
  count : Int32,
  offset : Double,
) -> ListRegion {
  let first = if offset <= 0.0 {
    0
  } else {
    (offset / ROW_HEIGHT).floor().to_int()
  }
  {
    kind,
    id,
    viewport,
    content_height: ROW_HEIGHT * count.to_double(),
    row_height: ROW_HEIGHT,
    first_index: first,
  }
}

///|
fn palette_layout(width : Double, height : Double) -> PaletteRegion {
  let panel_width = if width - 80.0 < 600.0 { width - 80.0 } else { 600.0 }
  let panel_height = if height - 100.0 < 430.0 { height - 100.0 } else { 430.0 }
  let panel_x = (width - panel_width) / 2.0
  let panel_y = (height - panel_height) / 2.0
  let panel = lrect(panel_x, panel_y, panel_width, panel_height)
  let field = lrect(panel_x + 20.0, panel_y + 66.0, panel_width - 40.0, 40.0)
  let list = lrect(
    panel_x + 20.0,
    panel_y + 120.0,
    panel_width - 40.0,
    panel_height - 172.0,
  )
  let rows : Array[@primitives.Rect] = []
  let row_height = 32.0
  let visible = (list.size().height() / row_height).floor().to_int()
  let count = if visible > 8 { 8 } else if visible < 0 { 0 } else { visible }
  for index in 0..<count {
    rows.push(
      lrect(
        list.left(),
        list.top() + index.to_double() * row_height,
        list.size().width(),
        row_height,
      ),
    )
  }
  {
    overlay: lrect(0.0, 0.0, width, height),
    panel,
    title: lrect(panel_x + 20.0, panel_y + 18.0, panel_width - 40.0, 24.0),
    field,
    list,
    footer: lrect(
      panel_x + 20.0,
      panel_y + panel_height - 40.0,
      panel_width - 40.0,
      18.0,
    ),
    rows,
  }
}

///|
pub fn layout(state : DemoState, width : Double, height : Double) -> UiLayout {
  let viewport = lrect(0.0, 0.0, width, height)
  let wide = width >= 920.0
  let sidebar_width = if wide { SIDEBAR_WIDE } else { SIDEBAR_RAIL }
  let sidebar = lrect(0.0, 0.0, sidebar_width, height)
  let content_x = sidebar_width + 28.0
  let content_width = width - content_x - 28.0
  let header = lrect(content_x, 26.0, content_width, 64.0)
  let status = lrect(content_x, height - 38.0, content_width, 18.0)
  let content = lrect(content_x, 106.0, content_width, height - 154.0)
  let nav_width = sidebar_width - 32.0
  let nav_rects = flex_column(
    16.0,
    118.0,
    nav_width,
    [44.0, 44.0, 44.0, 44.0],
    6.0,
  )
  let nav : Array[WidgetRegion] = []
  let pages = Page::all()
  for index in 0..<pages.length() {
    if index < nav_rects.length() {
      nav.push(
        lregion(100UL + index.to_uint64(), Nav(pages[index]), nav_rects[index]),
      )
    }
  }
  let palette_button_width = if content_width < 520.0 { 118.0 } else { 150.0 }
  let palette_button = lregion(
    206UL,
    Button(OpenPalette),
    lrect(
      content_x + content_width - palette_button_width,
      38.0,
      palette_button_width,
      32.0,
    ),
  )
  let mut cards : Array[@primitives.Rect] = []
  let mut buttons : Array[WidgetRegion] = []
  let mut note_field : WidgetRegion? = None
  let mut activity : ListRegion? = None
  let mut list : ListRegion? = None
  let swatches : Array[@primitives.Rect] = []
  let content_bottom = content.top() + content.size().height()
  match state.page {
    Overview => {
      let columns = if content_width >= 700.0 { 3 } else { 1 }
      let stat_rects = if columns == 3 {
        flex_row(content.left(), content.top(), content_width, 96.0, 3, 14.0)
      } else {
        flex_column(
          content.left(),
          content.top(),
          content_width,
          [96.0, 96.0, 96.0],
          14.0,
        )
      }
      for rect in stat_rects {
        cards.push(rect)
      }
      let rows = if columns == 3 { 1 } else { 3 }
      let action_y = content.top() +
        rows.to_double() * 96.0 +
        (rows - 1).to_double() * 14.0 +
        18.0
      buttons = place_buttons(
        content.left(),
        action_y,
        content_width,
        [(Increment, 128.0), (Reset, 92.0), (Copy, 132.0), (CycleAccent, 146.0)],
        10.0,
        40.0,
      )
      let action_rows = if buttons.length() > 4 { 2 } else { 1 }
      let action_bottom = action_y +
        action_rows.to_double() * 40.0 +
        (action_rows - 1).to_double() * 10.0
      let note_top = action_bottom + 18.0
      let note_card = lrect(content.left(), note_top, content_width, 124.0)
      cards.push(note_card)
      let note_rect = lrect(
        note_card.left() + 20.0,
        note_card.top() + 56.0,
        note_card.size().width() - 40.0,
        40.0,
      )
      note_field = Some(lregion(300UL, NoteField, note_rect))
      let activity_top = note_top + 140.0
      let activity_height = content_bottom - activity_top
      let activity_card = lrect(
        content.left(),
        activity_top,
        content_width,
        if activity_height < 120.0 {
          120.0
        } else {
          activity_height
        },
      )
      cards.push(activity_card)
      let viewport = lrect(
        activity_card.left() + 16.0,
        activity_card.top() + 50.0,
        activity_card.size().width() - 32.0,
        activity_card.size().height() - 76.0,
      )
      activity = Some(
        layout_region_for_list(
          Activity,
          401UL,
          viewport,
          state.activity_count(),
          state.scroll_activity.offset().y(),
        ),
      )
    }
    Controls => {
      let two_columns = content_width >= 700.0 &&
        content.size().height() >= 460.0
      if two_columns {
        let card_width = (content_width - 16.0) / 2.0
        let first = lrect(content.left(), content.top(), card_width, 210.0)
        let second = lrect(
          content.left() + card_width + 16.0,
          content.top(),
          card_width,
          210.0,
        )
        let third = lrect(
          content.left(),
          content.top() + 226.0,
          card_width,
          220.0,
        )
        let fourth = lrect(
          content.left() + card_width + 16.0,
          content.top() + 226.0,
          card_width,
          220.0,
        )
        cards = [first, second, third, fourth]
        buttons = place_buttons(
          first.left() + 18.0,
          first.top() + 56.0,
          card_width - 36.0,
          [
            (Increment, (card_width - 46.0) / 2.0),
            (ToggleLoading, (card_width - 46.0) / 2.0),
            (Disabled, (card_width - 46.0) / 2.0),
            (Copy, (card_width - 46.0) / 2.0),
          ],
          10.0,
          38.0,
        )
        buttons.push(
          lregion(
            207UL,
            Button(OpenPaletteCard),
            lrect(third.left() + 18.0, third.top() + 62.0, 180.0, 40.0),
          ),
        )
        let note_rect = lrect(
          second.left() + 18.0,
          second.top() + 70.0,
          card_width - 36.0,
          40.0,
        )
        note_field = Some(lregion(300UL, NoteField, note_rect))
        let swatch_y = third.top() + 126.0
        for index in 0..<3 {
          swatches.push(
            lrect(
              third.left() + 18.0 + index.to_double() * 44.0,
              swatch_y,
              32.0,
              32.0,
            ),
          )
        }
      } else {
        let first = lrect(content.left(), content.top(), content_width, 168.0)
        let second = lrect(
          content.left(),
          content.top() + 184.0,
          content_width,
          150.0,
        )
        let third = lrect(
          content.left(),
          content.top() + 350.0,
          content_width,
          170.0,
        )
        cards = [first, second, third]
        let button_width = (content_width - 52.0) / 2.0
        buttons = place_buttons(
          first.left() + 18.0,
          first.top() + 52.0,
          content_width - 36.0,
          [
            (Increment, button_width),
            (ToggleLoading, button_width),
            (Disabled, button_width),
            (Copy, button_width),
          ],
          10.0,
          34.0,
        )
        buttons.push(
          lregion(
            207UL,
            Button(OpenPaletteCard),
            lrect(third.left() + 18.0, third.top() + 56.0, 180.0, 38.0),
          ),
        )
        note_field = Some(
          lregion(
            300UL,
            NoteField,
            lrect(
              second.left() + 18.0,
              second.top() + 58.0,
              content_width - 36.0,
              40.0,
            ),
          ),
        )
        for index in 0..<3 {
          swatches.push(
            lrect(
              third.left() + 18.0 + index.to_double() * 44.0,
              third.top() + 118.0,
              32.0,
              32.0,
            ),
          )
        }
      }
    }
    Lists => {
      let card = lrect(
        content.left(),
        content.top(),
        content_width,
        content.size().height(),
      )
      cards.push(card)
      let viewport = lrect(
        card.left() + 18.0,
        card.top() + 54.0,
        card.size().width() - 36.0,
        card.size().height() - 86.0,
      )
      list = Some(
        layout_region_for_list(
          Items,
          402UL,
          viewport,
          LIST_ROWS,
          state.scroll_list.offset().y(),
        ),
      )
    }
    About => {
      let first = lrect(content.left(), content.top(), content_width, 214.0)
      let second = lrect(
        content.left(),
        content.top() + 230.0,
        content_width,
        214.0,
      )
      cards = [first, second]
    }
  }
  {
    viewport,
    sidebar,
    header,
    content,
    status,
    nav,
    palette_button,
    buttons,
    note_field,
    activity,
    list,
    palette: palette_layout(width, height),
    cards,
    swatches,
    page: state.page,
  }
}
