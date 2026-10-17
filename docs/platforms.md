# Platform status

| Platform | Status | Entry | Host |
| --- | --- | --- | --- |
| macOS | Working | `src/app` | AppKit + Metal + CoreText |
| Web | Working preview | `src/web` | Canvas 2D + DOM input |
| Linux | Planned | TBD | Wayland/X11 + GLES |
| Windows | Working preview | `windows-app/src/windows` | Win32 + D3D11 + DirectWrite |

## macOS

- `./build.sh` builds and launches `build/GpuiMacDemo.app`.
- `./build.sh --smoke` runs synthetic input and writes 10 PNG/PPM frames.
- MoonBit packages resolve from published `f4ah6o/gpui@0.9.0`.
- Native builds additionally use a `gpui.mbt` checkout for the Objective-C
  shim. The demo builder accepts `--gpui-root` / `GPUI_ROOT`.

## Web

- `./scripts/build_web.sh` writes `web/moonbit.js`.
- Serve `web/` over HTTP; do not open it with `file://`.
- `node scripts/smoke_web.mjs` drives headless Chrome through the DevTools
  protocol and writes screenshots to `build/web-smoke/`.
- The browser host uses Canvas 2D and a deterministic text approximation. It
  has no IME, native menu bar, general accessibility tree or clipboard bridge.

## Windows

- `windows-app` is a separate MoonBit module using the shared `src/native`
  controller and `platform/windows_app` for DirectWrite and window startup.
- `scripts/build_windows.ps1 -Mode smoke` drives the synthetic event queue and
  frame readback; artifacts go to `build/windows-smoke/`.
- Physical input, IME and UI Automation are not claimed. One HWND only.
- `windows-app` uses its own local `moon.work` only to include the sibling demo
  module; gpui.mbt 0.9.0 is resolved from Mooncakes. See [Windows demo](windows.md).

## Linux

The Linux entry will reuse `src/native` and add a Wayland/X11 host adapter."

## Support claims

This repository is a proof of concept. A "working" status means the checked-in
smoke flow passes on the development machine; it is not a production support
tier.
