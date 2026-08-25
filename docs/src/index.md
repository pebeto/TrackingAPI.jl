```@meta
CurrentModule = DearDiary
```

```@raw html
<script async defer src="https://buttons.github.io/buttons.js"></script>
```

# DearDiary.jl
*An ML experiment tracker written in Julia.*

```@raw html
<a class="github-button"
  href="https://github.com/JuliaAI/DearDiary.jl"
  data-icon="octicon-star"
  data-size="large"
  data-show-count="true"
  aria-label="Star JuliaAI/DearDiary.jl on GitHub">
  Star</a>
```

```@raw html
<img src="assets/deardiary-logo.svg" width="200" align="right" />
```

The [Installation](@ref) and [Quickstart](@ref) pages cover initial setup.

## Features
- **Tracking surface**: projects, experiments, iterations, parameters, metrics, tagged resources. Iterations form parent/child trees for HPO sweeps and distributed workers, and a status enum records failures with the captured exception text.
- **Server + client**: built-in REST API for remote logging and a native Julia client (`DearDiary.connect`, `with_iteration`, …) that auto-finalises iterations whether the body returns or throws.
- **Environment capture and replay**: every iteration records a `Manifest.toml` snapshot, the Julia version, and the git SHA. `DearDiary.restore(iteration_id)` writes the captured environment to a fresh directory for `Pkg.instantiate`.
- **Pluggable storage**: single-file DuckDB metadata store. Artifact bytes live inline, on a local filesystem, or in any S3-compatible object store (AWS S3, MinIO, Cloudflare R2). `migrate_artifacts!` moves rows between backends on a live database.

## Motivation
Reproducible ML depends on knowing what code, data, and environment produced each result. Established trackers such as MLflow, Weights & Biases, and Aim are Python-first, and Python environment capture commonly records dependency specifications that the installer re-resolves at install time. DearDiary is Julia-native and persists the `Manifest.toml` for each run, so the captured dependency environment can be reconstructed later by running `DearDiary.restore(iteration_id)`. The same tracking API applies whether the database is a single-file DuckDB store on a laptop or a multi-worker S3-backed deployment.

## Contributing
Open an issue or pull request on the [GitHub repository](https://github.com/JuliaAI/DearDiary.jl). Follow the existing [code style](https://github.com/JuliaDiff/BlueStyle) and include tests for new features.
