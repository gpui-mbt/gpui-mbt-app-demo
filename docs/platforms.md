# Platform status

| Platform | Status | Entry | Host |
| --- | --- | --- | --- |
| macOS | Working | `src/app` | AppKit + Metal + CoreText |
| Web | Working preview | `src/web` | Canvas 2D + DOM input |
| Linux | Planned | TBD | Wayland/X11 + GLES |
| Windows | Planned | TBD | Win32 + D3D11 |

## macOS

- `./build.sh` builds and launches `build/GpuiMacDemo.app`.
- `./build.sh --smoke` runs synthetic input and writes 10 PNG/PPM frames.
- Native builds currently use a `gpui.mbt` checkout for the Objective-C shim.
  The demo builder accepts `--gpui-root` / `GPUI_ROOT`.

## Web

- `./scripts/build_web.sh` writes `web/moonbit.js`.
- Serve `web/` over HTTP; do not open it with `file://`.
- `node scripts/smoke_web.mjs` drives headless Chrome through the DevTools
  protocol and writes screenshots to `build/web-smoke/`.
- The browser host uses Canvas 2D and a deterministic text approximation. It
  has no IME, native menu bar, general accessibility tree or clipboard bridge.

## Linux / Windows

These entries will be added once dedicated runners are available. The shared
model and scene already avoid platform-specific imports; each entry needs a
host loop, input translation, text measurement and a windowing adapter.

## Support claims

This repository is a proof of concept. A "working" status means the checked-in
smoke flow passes on the development machine; it is not a production support
tier.
