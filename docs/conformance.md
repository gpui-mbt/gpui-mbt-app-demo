# Relationship to gpui-conformance

[`gpui-conformance`](https://github.com/gpui-mbt/gpui-conformance) is the
comparison and evidence repository. Its browser lab pairs Rust GPUI and
gpui.mbt behavior; its native fixtures are bounded evidence processes, not a
user-facing application.

This repository is the downstream demo/consumer:

- it composes a real application from the reusable `app`/`scene` APIs;
- it is allowed to change UI and platform coverage independently of pinned
  conformance evidence;
- its smoke screenshots are demo evidence, not conformance claims.

When a demo behavior needs a formal comparison, add the scenario to
`gpui-conformance` instead of copying the demo into that repository.
