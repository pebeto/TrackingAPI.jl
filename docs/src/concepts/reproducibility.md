# Reproducibility

Reproducing a model result requires recovering the code, data, and environment that produced
it. DearDiary addresses the environment part by capturing the Julia dependency environment
and git state at the moment a run starts and storing it alongside the iteration's metrics and
parameters.

## What gets captured

Each [`Iteration`](@ref DearDiary.Iteration) can hold an [`EnvironmentSnapshot`](@ref):

| Field | Content |
|---|---|
| `julia_version` | `string(VERSION)` at capture time |
| `git_sha` | HEAD commit SHA, or `""` outside a git repo |
| `git_dirty` | `true` when the working tree had uncommitted changes |
| `entrypoint` | Path of the running script (`PROGRAM_FILE`), or `""` in the REPL |
| `project_toml` | Verbatim `Project.toml` of the active environment |
| `manifest_toml` | Verbatim `Manifest.toml` of the active environment |

The snapshot is taken by [`capture_environment`](@ref) and persisted on the iteration row
by [`snapshot_environment!`](@ref). Both functions never throw: a missing git repo, an
unresolved environment, and a REPL session all fall back to empty strings.

## Automatic capture

[`with_iteration`](@ref) calls [`snapshot_environment!`](@ref) right after creating the
iteration, but only for driver (top-level) runs. Child iterations, created with
`parent_iteration_id` set, skip the snapshot by default so HPO trials and distributed
workers do not all capture redundant copies of the same environment. Pass `snapshot=true`
to override.

## Manual capture

To attach a snapshot outside the `with_iteration` flow, call `snapshot_environment!`
directly:

```julia
iteration_id, _ = create_iteration(experiment_id)
snapshot_environment!(iteration_id)
```

`capture_environment` returns the snapshot struct without persisting it, which is useful
for inspection or for shipping the capture across a process boundary in a distributed setup:

```julia
snap = capture_environment()
snap.julia_version  # "1.10.4"
snap.git_sha        # "a3f1c9..."
```

## Restoring an environment

[`restore`](@ref) writes the captured `Project.toml` and `Manifest.toml` into a fresh
directory. It does not activate the project or run `Pkg.instantiate`; those steps are left
to the caller.

```julia
result = DearDiary.restore(iteration_id)

using Pkg
Pkg.activate(result.project_path)
Pkg.instantiate()
```

`result` is a [`RestoreResult`](@ref) that also carries `julia_version`, `git_sha`,
`git_dirty`, and `entrypoint`, so callers can check whether the captured commit was clean and
optionally check out the exact SHA before re-running.

## Manifest.toml compared with pip freeze

`pip freeze` records direct and transitive dependency versions as version constraints. On
install, the solver re-runs and may pick different patch versions depending on what is
available at that moment. Julia's `Manifest.toml` records the exact resolved tree, including
hashes. `Pkg.instantiate` fetches the pinned versions without re-resolving them. The captured
manifest reproduces the same tree regardless of how the registry has moved on since the
original run.

For the complete how-to see [Reproduce a past run](@ref).
