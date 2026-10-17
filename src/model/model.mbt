///|
pub(all) enum Page {
  Overview
  Controls
  Lists
  About
} derive(Eq)

///|
pub extend Page with Eq::{not_equal, equal}

///|
pub fn Page::index(self : Page) -> Int32 {
  match self {
    Overview => 0
    Controls => 1
    Lists => 2
    About => 3
  }
}

///|
pub fn Page::from_index(index : Int32) -> Page? {
  match index {
    0 => Some(Overview)
    1 => Some(Controls)
    2 => Some(Lists)
    3 => Some(About)
    _ => None
  }
}

///|
pub fn Page::label(self : Page) -> String {
  match self {
    Overview => "Overview"
    Controls => "Controls"
    Lists => "Lists"
    About => "About"
  }
}

///|
pub fn Page::short_label(self : Page) -> String {
  match self {
    Overview => "OV"
    Controls => "CT"
    Lists => "LS"
    About => "AB"
  }
}

///|
pub fn Page::subtitle(self : Page) -> String {
  match self {
    Overview => "A portable gpui.mbt playground for native and web hosts."
    Controls =>
      "Shared Button, TextField and CommandPalette models with platform adapters."
    Lists => "Scroll state, clipped rows, keyboard selection and pointer focus."
    About => "Reusable app runtime, scene builder and CoreText text helpers."
  }
}

///|
pub fn Page::all() -> Array[Page] {
  [Overview, Controls, Lists, About]
}

///|
pub(all) enum ListKind {
  Activity
  Items
}

///|
pub(all) enum Intent {
  Go(Page)
  Increment
  Reset
  CopySummary
  ToggleLoading
  CycleAccent
  FocusNote
  Quit
}

///|
pub const NOTE_FIELD_ID : UInt64 = 300UL

///|
pub const PALETTE_FIELD_ID : UInt64 = 9002UL

///|
pub const LIST_ROWS : Int32 = 40

///|
pub const ROW_HEIGHT : Double = 34.0

///|
pub const MAX_ACTIVITY : Int32 = 32

///|
/// Application state owned by the demo. List scroll positions use the shared
/// immutable ScrollState; controls and native services stay in the app package.
pub(all) struct DemoState {
  mut page : Page
  mut accent : Accent
  mut clicks : Int32
  mut palette_actions : Int32
  mut loading : Bool
  mut note : String
  mut activity : Array[String]
  mut activity_selected : Int32?
  mut list_selected : Int32?
  mut scroll_activity : @element.ScrollState
  mut scroll_list : @element.ScrollState
  mut status : String
}

///|
fn demo_size(width : Double, height : Double) -> @primitives.Size {
  @primitives.Size::new(width, height).unwrap()
}

///|
pub fn DemoState::new() -> DemoState {
  {
    page: Overview,
    accent: Teal,
    clicks: 0,
    palette_actions: 0,
    loading: false,
    note: "",
    activity: ["Press Cmd/Ctrl+K for commands", "Demo ready"],
    activity_selected: None,
    list_selected: None,
    scroll_activity: @element.ScrollState::new(
      demo_size(1.0, 1.0),
      demo_size(1.0, 1.0),
    ),
    scroll_list: @element.ScrollState::new(
      demo_size(1.0, 1.0),
      demo_size(1.0, 1.0),
    ),
    status: "Ready",
  }
}

///|
pub fn DemoState::record(self : DemoState, text : String) -> Unit {
  let next : Array[String] = [text]
  for item in self.activity {
    next.push(item)
  }
  while next.length() > MAX_ACTIVITY {
    ignore(next.pop())
  }
  self.activity = next
}

///|
pub fn DemoState::increment(self : DemoState) -> Unit {
  self.clicks += 1
  self.status = "Incremented to \{self.clicks}"
  self.record("Increment -> \{self.clicks}")
}

///|
pub fn DemoState::toggle_loading(self : DemoState) -> Unit {
  self.loading = !self.loading
  self.status = if self.loading {
    "Increment is loading"
  } else {
    "Increment is ready"
  }
  self.record(if self.loading { "Loading enabled" } else { "Loading cleared" })
}

///|
pub fn DemoState::cycle_accent(self : DemoState) -> Unit {
  self.accent = self.accent.next()
  self.status = "Theme accent changed"
  self.record("Accent -> \{self.accent.label()}")
}

///|
pub fn DemoState::go(self : DemoState, page : Page) -> Unit {
  self.page = page
  self.status = "Opened \{page.label()}"
  self.record("Opened \{page.label()}")
}

///|
pub fn DemoState::reset(self : DemoState) -> Unit {
  self.clicks = 0
  self.palette_actions = 0
  self.loading = false
  self.activity_selected = None
  self.list_selected = None
  self.activity = ["Demo reset"]
  self.status = "Reset"
}

///|
pub fn DemoState::note_len(self : DemoState) -> Int32 {
  self.note.length()
}

///|
pub fn DemoState::activity_count(self : DemoState) -> Int32 {
  self.activity.length()
}

///|
pub fn DemoState::list_item(self : DemoState, index : Int32) -> String {
  ignore(self)
  match Page::from_index(index % 4) {
    Some(page) => "Row \{index + 1}  /  \{page.label()} view"
    None => "Row \{index + 1}"
  }
}

///|
pub fn DemoState::summary(self : DemoState) -> String {
  "gpui.mbt macOS demo | page=\{self.page.label()} clicks=\{self.clicks} palette=\{self.palette_actions} noteLen=\{self.note_len()} accent=\{self.accent.label()}"
}

///|
pub fn DemoState::set_status(self : DemoState, status : String) -> Unit {
  self.status = status
}

///|
pub fn DemoState::apply_intent(self : DemoState, intent : Intent) -> Bool {
  match intent {
    Go(page) => {
      self.go(page)
      true
    }
    Increment => {
      if self.loading {
        self.status = "Increment is loading"
      } else {
        self.increment()
      }
      true
    }
    Reset => {
      self.reset()
      true
    }
    ToggleLoading => {
      self.toggle_loading()
      true
    }
    CycleAccent => {
      self.cycle_accent()
      true
    }
    CopySummary | FocusNote | Quit => false
  }
}

///|
pub fn DemoState::sync_activity_scroll(
  self : DemoState,
  viewport : @primitives.Size,
) -> Unit {
  let content = demo_size(
    viewport.width(),
    ROW_HEIGHT * self.activity_count().to_double(),
  )
  self.scroll_activity = self.scroll_activity.with_sizes(viewport, content)
}

///|
pub fn DemoState::sync_list_scroll(
  self : DemoState,
  viewport : @primitives.Size,
) -> Unit {
  let content = demo_size(viewport.width(), ROW_HEIGHT * LIST_ROWS.to_double())
  self.scroll_list = self.scroll_list.with_sizes(viewport, content)
}

///|
pub fn DemoState::scroll_by(
  self : DemoState,
  kind : ListKind,
  dx : Double,
  dy : Double,
) -> Unit {
  let next = match kind {
    Activity => self.scroll_activity.scroll_by(dx, dy)
    Items => self.scroll_list.scroll_by(dx, dy)
  }
  match next {
    Err(_) => ()
    Ok(value) =>
      match kind {
        Activity => self.scroll_activity = value
        Items => self.scroll_list = value
      }
  }
}

///|
pub fn DemoState::select(
  self : DemoState,
  kind : ListKind,
  index : Int32,
) -> Unit {
  let count = match kind {
    Activity => self.activity_count()
    Items => LIST_ROWS
  }
  if count == 0 {
    return
  }
  let clamped = if index < 0 {
    0
  } else if index >= count {
    count - 1
  } else {
    index
  }
  let row = @primitives.Rect::new(
    0.0,
    row_index(clamped).to_double() * ROW_HEIGHT,
    1.0,
    ROW_HEIGHT,
  ).unwrap()
  match kind {
    Activity => {
      self.activity_selected = Some(clamped)
      self.scroll_activity = self.scroll_activity.ensure_visible(row)
    }
    Items => {
      self.list_selected = Some(clamped)
      self.scroll_list = self.scroll_list.ensure_visible(row)
    }
  }
  self.status = "Selected row \{clamped + 1}"
}

///|
fn row_index(index : Int32) -> Int32 {
  index
}

///|
pub fn DemoState::move_selection(
  self : DemoState,
  kind : ListKind,
  delta : Int32,
) -> Unit {
  let current = match kind {
    Activity => self.activity_selected
    Items => self.list_selected
  }
  let count = match kind {
    Activity => self.activity_count()
    Items => LIST_ROWS
  }
  let next = match current {
    None => if delta < 0 { count - 1 } else { 0 }
    Some(index) => index + delta
  }
  self.select(kind, next)
}

///|
pub fn DemoState::clear_selection(self : DemoState, kind : ListKind) -> Unit {
  match kind {
    Activity => self.activity_selected = None
    Items => self.list_selected = None
  }
}
