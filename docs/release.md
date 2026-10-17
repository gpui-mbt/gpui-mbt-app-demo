# Release and publication checklist

The demo currently uses a pre-release gpui.mbt branch because the reusable
`app`, `SceneBuilder` and `platform/macos_app` APIs are not in a published
package yet.

## When gpui.mbt ships the APIs

1. Update `moon.mod` to the published version (for example `0.7.3`).
2. Set the repository variable `GPUI_REF` to `main`:
   `gh variable set GPUI_REF --body main`.
3. Re-run `Demo CI` and `./build.sh --smoke` / `node scripts/smoke_web.mjs`.
4. Confirm the repository is public. It is currently public at
   <https://github.com/gpui-mbt/gpui-mbt-app-demo>.
5. Re-deploy the Pages workflow. Pages is already enabled at
   <https://gpui-mbt.github.io/gpui-mbt-app-demo/>; the portable-web CI job also
   uploads `web-demo` as an artifact.
6. Keep the local `moon.work` override for framework development only.

## Native shim

Native macOS builds still need a gpui.mbt checkout for `platform/macos/*.m` and
`platform/macos_text/core_text.c`. The builder exposes `--gpui-root` /
`GPUI_ROOT`. A future gpui.mbt release should package or install those sources
so a standalone clone can build the app without a sibling checkout.
