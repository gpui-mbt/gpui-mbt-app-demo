# Release and publication checklist

The demo pins **`f4ah6o/gpui@0.10.6`**. The reusable `app`, `SceneBuilder`,
`platform/macos_app` and `platform/windows_app` APIs are published as of this
release.

## Current lanes

- **Published lane** (push/PR): resolves `0.10.6` from Mooncakes and runs the
  portable checks plus the web smoke.
- **gpui.mbt main lane** (manual dispatch): checks out `gpui.mbt`, creates a
  local `moon.work`, and tests the demo against framework main.
- **macOS lane**: uses published MoonBit packages and checks out `gpui.mbt`
  only for the native Objective-C/CoreText shim sources.
- **Pages**: deploys `web/` to <https://gpui-mbt.github.io/gpui-mbt-app-demo/>.
- **Windows lane**: resolves gpui.mbt 0.10.6 from Mooncakes and creates a
  module-local `windows-app/moon.work` that includes the sibling demo module.

## When bumping gpui.mbt

1. Update `moon.mod` to the new published version.
2. Run `moon update`, then `moon check/test` without `moon.work`.
3. Re-run `./build.sh --smoke` and `node scripts/smoke_web.mjs`.
4. Let CI and Pages redeploy.
5. Keep the local override (`scripts/use-local-gpui.sh`) for framework
   development only; remove `moon.work` before testing the published package.

## Windows follow-up

`platform/windows_app` is published in 0.10.6. The Windows lane now uses the
published package. `-GpuiRoot` remains available for local framework
development, but is not required.

## Native shim

Native macOS builds still need a gpui.mbt checkout for `platform/macos/*.m` and
`platform/macos_text/core_text.c`. The builder exposes `--gpui-root` /
`GPUI_ROOT`. A future gpui.mbt release should package or install those sources
so a standalone clone can build the app without a sibling checkout.
