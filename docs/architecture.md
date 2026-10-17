# Architecture

The demo separates portable application behavior from host adapters.

```text
src/model/     DemoState, intents, theme, responsive layout, widget IDs
src/scene/     portable frame composition over SceneBuilder
src/app/       macOS AppKit host, input adapter, smoke driver
src/web/       browser controller, input bridge and Canvas 2D host
scripts/       local dependency override, app builder, web build and smoke
```

## Shared model

`src/model` owns page state, activity history, list selection and scroll,
palette actions, accent selection, buttons and responsive layout. It has no
AppKit, Metal, browser or CoreText dependency.

## Shared scene

`src/scene.SceneInputs` receives:

- `DemoState` and `UiLayout`
- shared `Button`, `TextField` and `CommandPalette` values
- an `ElementTree` for focus and hit testing
- hover and pointer state
- a platform text-measurement callback
- a display label such as `AppKit + Metal` or `Canvas 2D`

`SceneInputs.build_scene` composes the same scene snapshot for every host. The
macOS adapter uses CoreText metrics; the web adapter uses a deterministic
monospace approximation. Scene items remain the bounded v1 quad and text-run
subset.

## Host adapters

The macOS entry uses `platform/macos_app` for CoreText measurement, TextField
admission/hit testing, cursor state and the `app.WindowView` loop.

The web entry owns a MoonBit `WebController`, exposes a small string/JSON ABI
with `#export_name`, and runs without a bundler. `scripts/build_web.sh` compiles
`src/web` to `web/moonbit.js`; `web/host.js` forwards DOM pointer, keyboard and
wheel input and draws the snapshot with Canvas 2D.

Linux and Windows entries will reuse `src/model` and `src/scene` and add their
own host adapters. They are not implemented yet.
