# Quickstart

This page tracks one run end to end on a local database, with no server and no extra
packages. For remote logging see [Log from a remote client](@ref).

```@setup quickstart
using DearDiary
DearDiary.initialize_database(; file_name=joinpath(mktempdir(), "deardiary.db"))
```

Open the local database. It is created on first use.

```julia
using DearDiary
DearDiary.initialize_database()
```

Create a project and an experiment to hold the runs.

```@repl quickstart
project_id, _ = create_project("Iris classification")
experiment_id, _ = create_experiment(project_id, DearDiary.IN_PROGRESS, "Decision-tree sweep")
```

Open an iteration and log parameters and metrics. `with_iteration` marks the iteration
`SUCCEEDED` on a clean return or `FAILED` on a throw, and snapshots the environment.

```@repl quickstart
with_iteration(experiment_id) do iter
    create_parameter(iter.id, "max_depth", 7)
    create_metric(iter.id, "accuracy", 0.96)
end
```

Read the logged data back.

```@repl quickstart
iteration = last(get_iterations(experiment_id))
get_parameters(iteration.id)
get_metrics(iteration.id)
```
