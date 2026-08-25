# Embedded web UI

!!! warning "Experimental"
    The embedded web dashboard is experimental. Its DOM structure, URL paths,
    CSS class names, and the env vars listed below can all change without a
    deprecation cycle. Treat it as a local browsing convenience; do not build
    production tooling on top of its HTML or hard-code its routes into
    automation.

DearDiary boots a small in-process web dashboard alongside the REST API. It supports
browsing projects, experiments, and iterations recorded by the default user; inspecting
parameters and metric charts for any iteration; and following parent/child trial trees.

## Configuration

The UI starts by default. Three env vars control it:

```text
DEARDIARY_ENABLE_UI=true        # set to false to skip booting the UI server
DEARDIARY_UI_HOST=127.0.0.1     # bind address
DEARDIARY_UI_PORT=9001          # port the dashboard listens on
```

`DearDiary.run(; env_file=".env")` boots the REST API and the dashboard on their
respective ports. `DearDiary.stop()` closes both servers together.

## Dashboard contents

- **Sidebar:** A tree of projects, experiments, and iterations. Child
  trials nest under their driver iteration so lineage stays visible. Each
  iteration label carries a status glyph (`✓` succeeded, `▶` running,
  `✗` failed, `⊘` killed), a per-experiment ordinal, and a relative
  timestamp (example: `✓ Iteration 3 · 12m ago`). Link color (yellow
  running, red failed, purple killed, default succeeded) reinforces the
  status. The selected row keeps a highlight until another row is
  clicked. Ordinals are local to each experiment and are derived from
  creation order, so deleting a row renumbers the remaining iterations.
- **Detail pane:** A heading carrying the per-experiment ordinal, a status
  badge, the experiment name, the canonical iteration id on its own `ID:`
  line, created and ended timestamps, the run duration, the parent
  iteration's ordinal when present, any run notes, any tags as chips, the
  parameter table, and an inline-SVG chart of every metric series keyed by
  step. Hovering a point shows a tooltip with the metric name, step, and
  value. The chart renders server-side with no external JS bundle.
- **Environment card:** The reproducibility snapshot captured for the
  iteration: Julia version, git commit (flagged when the working tree was
  dirty), and entrypoint. Iterations without a snapshot, including child
  runs that inherit the driver's, report that none was captured.
- **Browser tab title:** Tracks the selected iteration as
  `#3 · ExperimentName · DearDiary`, using the same per-experiment ordinal
  as the sidebar. The landing page renders as plain `DearDiary`.
- **Docs link:** A `Docs ↗` anchor at the bottom of the sidebar opens
  this documentation site in a new tab.

## Disabling the UI

Set `DEARDIARY_ENABLE_UI=false` in the env file. The REST API on `DEARDIARY_PORT`
continues to run unchanged. Use this for a headless CI runner or a container image that
needs no browser-facing surface.

## Known limitations

- **Single user.** The dashboard reads as the seeded `default` user with no
  login screen and no multi-tenant view.
- **Read-only.** Mutate state through the REST API or the Julia client. The
  UI exposes no edit affordances.
- **WebSocket-driven title updates.** The browser tab title updates from the
  server via a live WebSocket. Slow connections may show stale title text for
  a second or two after a click.
- **Cold-start latency.** The first request after `DearDiary.run` takes a few
  seconds while Bonito boots its renderer. Subsequent requests serve in tens
  of milliseconds. A `PrecompileTools` workload absorbs part of this cost into
  `Pkg.precompile`.
