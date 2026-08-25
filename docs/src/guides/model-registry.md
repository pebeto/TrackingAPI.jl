# Register and stage models

[`DearDiary.Model`](@ref) and [`DearDiary.ModelVersion`](@ref) form a project-scoped
registry on top of the run-tracking entities. A `Model` is the named entry that downstream
serving code refers to (e.g. `"fraud-classifier"`); a `ModelVersion` is a concrete
checkpoint with lineage back to the [`Iteration`](@ref DearDiary.Iteration) that produced it, an optional
pointer at the artifact bytes in any configured storage backend, and a lifecycle
[`DearDiary.Stage`](@ref).

Versions transition through `NO_STAGE → STAGING → PRODUCTION → ARCHIVED`. Promoting a
version to `PRODUCTION` automatically demotes whichever sibling was previously in
`PRODUCTION`, preserving the "at most one production version per model" invariant.

```@setup model-registry
using DearDiary
DearDiary.initialize_database(; file_name=joinpath(mktempdir(), "deardiary.db"))
```

## Scaffold a project and an iteration

```@repl model-registry
project_id, _ = create_project("Fraud detection");
experiment_id, _ = create_experiment(project_id, DearDiary.IN_PROGRESS, "DT sweep");
iteration_id, _ = create_iteration(experiment_id);
create_parameter(iteration_id, "max_depth", 7);
create_metric(iteration_id, "accuracy", 0.96);
```

Save the trained model bytes as a [`Resource`](@ref DearDiary.Resource). Any serialisation format works; the
registry stores only the byte payload and its lineage.

```@repl model-registry
checkpoint_bytes = rand(UInt8, 1024);
resource_id, _ = create_resource(experiment_id, "fraud-clf.jlso", checkpoint_bytes);
```

## Register the model

A `Model` is a named entry: a stable identifier that persists across successive training
runs and model versions.

```@repl model-registry
model_id, _ = create_model(project_id, "fraud-classifier");
```

```@repl model-registry
get_model(model_id)
```

## Register a version

A `ModelVersion` ties a [`Resource`](@ref DearDiary.Resource) to the [`Iteration`](@ref DearDiary.Iteration) that produced it.
The per-model version number is assigned on insert as one greater than the model's current
highest version, and a uniqueness constraint keeps it distinct within the model:

```@repl model-registry
version_a_id, _ = create_modelversion(
    model_id, iteration_id, resource_id,
    "Decision tree, max_depth=7",
);
```

```@repl model-registry
version_a = get_modelversion(version_a_id)
```

A freshly registered version starts in [`DearDiary.NO_STAGE`](@ref). Promote it through the
lifecycle as evaluation results become available:

```@repl model-registry
update_modelversion(version_a_id, DearDiary.STAGING, nothing, nothing);
```

```@repl model-registry
update_modelversion(version_a_id, DearDiary.PRODUCTION, nothing, nothing);
```

## Roll forward to a new checkpoint

Train another iteration, register a second version, and promote it to `PRODUCTION`. The
previous production version is archived by the same `update_modelversion` call:

```@repl model-registry
iteration_b_id, _ = create_iteration(experiment_id);
create_parameter(iteration_b_id, "max_depth", 9);
create_metric(iteration_b_id, "accuracy", 0.974);
resource_b_id, _ = create_resource(experiment_id, "fraud-clf-v2.jlso", rand(UInt8, 1024));

version_b_id, _ = create_modelversion(
    model_id, iteration_b_id, resource_b_id,
    "Decision tree, max_depth=9",
);
update_modelversion(version_b_id, DearDiary.PRODUCTION, nothing, nothing);
```

The previous production version is now archived:

```@repl model-registry
get_modelversion(version_a_id).stage_id == (DearDiary.ARCHIVED |> Integer)
```

```@repl model-registry
get_modelversion(version_b_id).stage_id == (DearDiary.PRODUCTION |> Integer)
```

## Browsing the registry

[`get_modelversions`](@ref) returns the per-model history ordered by `version` ascending,
so finding the current production checkpoint is a single filter:

```@repl model-registry
versions = get_modelversions(model_id);
production = filter(v -> v.stage_id == (DearDiary.PRODUCTION |> Integer), versions);
production[1].version
```

The full lineage is reachable from `version.iteration_id` and `version.resource_id`:

```@repl model-registry
producing_iteration = (version_b_id |> get_modelversion).iteration_id |> get_iteration
```

```@repl model-registry
get_parameters(producing_iteration.id)
```

```@setup model-registry
DearDiary.close_database()
```
