# Parent and child iterations

An [`Iteration`](@ref DearDiary.Iteration) can declare another iteration as its parent via
`parent_iteration_id`, which models any one-to-many "owner run produced N child runs"
relationship: a hyperparameter sweep that spawns one trial per configuration, a nested
cross-validation outer loop that owns each fold, or a distributed training job whose driver
fans out to per-worker iterations. The parent must be in the same experiment as its children
(cross-experiment lineage is rejected), and each child also tracks its own
[`DearDiary.IterationStatus`](@ref) (`RUNNING` / `SUCCEEDED` / `FAILED` / `KILLED`).

```@setup child-iterations
using DearDiary
DearDiary.initialize_database(; file_name=joinpath(mktempdir(), "deardiary.db"))
```

## Scaffold a sweep

The driver iteration represents the sweep as a whole. Its parameters describe the search
space; its metrics summarise the result. Each configuration the sweep tries lives in a
child iteration that points back at the driver.

```@repl child-iterations
project_id, _ = create_project("Fraud detection");
experiment_id, _ = create_experiment(project_id, DearDiary.IN_PROGRESS, "Decision-tree sweep");

driver_id, _ = create_iteration(experiment_id);
create_parameter(driver_id, "max_depth_range", "2..10");
create_parameter(driver_id, "search", "grid");
```

## Spawn a child per trial

Each trial gets its own iteration with `parent_iteration_id` pointing at the driver. The
service layer validates that the parent exists and belongs to the same experiment. A
cross-experiment parent returns [`DearDiary.Unprocessable`](@ref), so a misconfigured
sweep cannot produce orphaned children.

```@repl child-iterations
trial_ids = String[];
for depth in 2:5
    trial_id, _ = create_iteration(experiment_id; parent_iteration_id=driver_id)
    create_parameter(trial_id, "max_depth", depth)
    create_metric(trial_id, "accuracy", 0.90 + 0.01 * depth)
    push!(trial_ids, trial_id)
end
trial_ids
```

## Auto-finalised trials with `with_iteration`

Real sweeps don't always succeed. A malformed configuration or an out-of-memory error can
take a trial down. The [`DearDiary.with_iteration`](@ref) helper opens a fresh child
iteration, runs the body, marks the row [`DearDiary.SUCCEEDED`](@ref) on a clean return,
or marks it [`DearDiary.FAILED`](@ref) with the captured exception text in `error_message`
and rethrows so the caller still sees the error:

```@repl child-iterations
succeeded_id = DearDiary.with_iteration(experiment_id; parent_iteration_id=driver_id) do iter
    create_parameter(iter.id, "max_depth", 6)
    create_metric(iter.id, "accuracy", 0.972)
    iter.id
end;
```

```@repl child-iterations
succeeded = get_iteration(succeeded_id);
(succeeded.status_id == (DearDiary.SUCCEEDED |> Integer), succeeded.error_message)
```

A trial that throws is captured the same way: the exception body is preserved on the row.

```@example child-iterations
failed_id = Ref{String}()
try
    DearDiary.with_iteration(experiment_id; parent_iteration_id=driver_id) do iter
        failed_id[] = iter.id
        error("OutOfMemoryError: max_depth=12 blew the heap")
    end
catch
    # The driver swallowed the exception so the rest of the sweep can carry on.
end
nothing # hide
```

```@repl child-iterations
failed = get_iteration(failed_id[]);
(failed.status_id == (DearDiary.FAILED |> Integer), failed.error_message)
```

## Walking the tree

[`get_child_iterations`](@ref) returns the direct children of a parent, ordered by id
ascending. Combine it with [`get_parameters`](@ref) and [`get_metrics`](@ref) to find the
best trial of a sweep:

```@repl child-iterations
children = get_child_iterations(driver_id);
(children |> length)
```

```@repl child-iterations
best = argmax(c -> get_metrics(c.id)[1].value, filter(c -> c.status_id == (DearDiary.SUCCEEDED |> Integer), children));
best_depth = get_parameters(best.id)[1].value
```

## Cascading deletes

Children are independent rows: deleting the parent does **not** delete its children.
The schema's foreign-key action sets each surviving child's `parent_iteration_id` to
`NULL`, so they continue to exist as standalone iterations until explicitly removed. This
preserves historical training results even when the driver run is pruned.

```@repl child-iterations
delete_iteration(driver_id);
get_iteration(succeeded_id).parent_iteration_id |> isnothing
```

## Distributed-worker pattern

The same `parent_iteration_id` field handles distributed training: one driver iteration
records the global run, while each worker opens its own child iteration on connect, logs
its metrics, and is auto-finalised when its task exits. The driver tracks aggregate metrics;
each worker tracks its slice.

```julia
using DearDiary, Distributed

# In the driver process:
client = DearDiary.connect("http://127.0.0.1:9000"; username="default", password="default")
driver = DearDiary.with_iteration(client, experiment_id) do driver
    @sync for worker_rank in 1:8
        @async with_iteration(client, experiment_id; parent_iteration_id=driver.id) do iter
            create_parameter(client, iter.id, "worker_rank", worker_rank)
            train_partition!(client, iter, worker_rank)
        end
    end
    driver
end
```

A worker that crashes records a [`DearDiary.FAILED`](@ref) row with the stack-trace text in
`error_message` while sibling workers and the driver continue.

```@setup child-iterations
DearDiary.close_database()
```
