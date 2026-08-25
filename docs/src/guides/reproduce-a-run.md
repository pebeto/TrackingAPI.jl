# Reproduce a past run

Every [`Iteration`](@ref DearDiary.Iteration) can carry a snapshot of the Julia environment that
produced it: `julia_version`, the HEAD commit SHA, the verbatim `Project.toml` and
`Manifest.toml` active at run start, and the entrypoint script. [`restore`](@ref) later
writes that snapshot back to disk so the pinned dependency tree can be `Pkg.instantiate`-d in
a fresh depot. Unlike a `pip freeze` file, which records version numbers and can re-resolve
transitive dependencies on install, `Manifest.toml` pins each package to a specific version
and tree hash, so `Pkg.instantiate` reinstalls the same package versions without re-resolving
them.

```@setup reproduce-a-run
using DearDiary
DearDiary.initialize_database(; file_name=joinpath(mktempdir(), "deardiary.db"))
```

## Capture happens automatically on the driver iteration

[`DearDiary.with_iteration`](@ref) calls [`snapshot_environment!`](@ref) right after
creating the iteration, but only when the new run has no parent. Driver runs capture a
snapshot; child runs (HPO trials, distributed workers) skip it and rely on the driver's copy.
The `snapshot` keyword overrides this default in either direction.

```@repl reproduce-a-run
project_id, _ = create_project("Repro Project");
experiment_id, _ = create_experiment(project_id, DearDiary.IN_PROGRESS, "Training");

iteration_id = DearDiary.with_iteration(experiment_id) do iter
    create_parameter(iter.id, "lr", 1e-3)
    iter.id
end;
```

```@repl reproduce-a-run
iteration = get_iteration(iteration_id);
iteration.julia_version
```

```@repl reproduce-a-run
iteration.git_sha |> length
```

```@repl reproduce-a-run
iteration.entrypoint, iteration.git_dirty
```

## Capture an iteration manually

To attach a snapshot outside the `with_iteration` flow (for example, in a long-lived
service that opens iterations imperatively), call [`snapshot_environment!`](@ref) directly:

```@repl reproduce-a-run
manual_id, _ = create_iteration(experiment_id);
DearDiary.snapshot_environment!(manual_id; entrypoint="train.jl");
get_iteration(manual_id).entrypoint
```

[`DearDiary.capture_environment`](@ref) returns the snapshot without persisting it, useful
for inspection or shipping the capture across a process boundary:

```@repl reproduce-a-run
snapshot = DearDiary.capture_environment();
snapshot.julia_version
```

## Replay an environment

[`restore`](@ref) writes the captured `Project.toml` and `Manifest.toml` into a fresh
directory under `depot`. It does **not** activate the project or run `Pkg.instantiate`.
That is left to the caller so the function stays side-effect-free outside the temp tree.

```@repl reproduce-a-run
depot = mktempdir();
result = DearDiary.restore(iteration_id; depot=depot)
```

```@repl reproduce-a-run
isfile(joinpath(result.project_path, "Project.toml")), isfile(joinpath(result.project_path, "Manifest.toml"))
```

The on-disk files are byte-identical to what was captured. Loading them with `using Pkg;
Pkg.activate(result.project_path); Pkg.instantiate()` reinstalls the same pinned package
versions the iteration ran against:

```julia
using Pkg
Pkg.activate(result.project_path)
Pkg.instantiate()
# ...then optionally check out the captured commit and run the entrypoint:
# `git checkout $(result.git_sha)` and `julia --project=$(result.project_path) $(result.entrypoint)`
```

## What is and is not captured

| Captured | Not captured |
|---|---|
| Julia version (`string(VERSION)`) | OS / kernel / glibc |
| HEAD commit SHA + dirty bit | The actual code if `git_dirty == true` and changes are uncommitted |
| Active `Project.toml` (verbatim) | Per-package C library versions outside the JLL system |
| Active `Manifest.toml` (verbatim) | Datasets used by the run (separate concern) |
| Entrypoint script path | Runtime config files outside the project |

If `git_dirty` is `true`, the captured Manifest alone does not describe the code that ran:
uncommitted source changes must be reapplied manually. Reproducible jobs should be run from
a clean working tree, and the `git_dirty` flag records whether the tree was clean at capture
time.

```@setup reproduce-a-run
DearDiary.close_database()
```
