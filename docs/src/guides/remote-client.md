# Log from a remote client

When the training script runs on a different machine, use the bundled Julia client. Most
CRUD verbs have a [`Client`](@ref)-aware overload. Tags are the exception: attach one with
`add_tag`, since the local `create_tag` has no REST counterpart. [`with_iteration`](@ref)
auto-finalises an iteration on success or exception. Start the server first (see
[Run the server](@ref)).

```julia
using DearDiary

client = DearDiary.connect(
    "http://server.example:9000"; username="alice", password="secret",
)

project_id = create_project(client, "Iris classification")
experiment_id = create_experiment(
    client, project_id, DearDiary.IN_PROGRESS, "Decision tree sweep",
)

with_iteration(client, experiment_id) do iter
    create_parameter(client, iter.id, "max_depth", 4)
    create_metric(client, iter.id, "accuracy", 0.96)
end
```

See the [Client and REST API](@ref) reference for the full helper list.
