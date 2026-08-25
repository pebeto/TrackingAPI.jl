# Usage modes

DearDiary can run in two modes: offline (direct function calls against a local database)
and server (REST API with a network client). Both modes share the same entity model and
produce identical data; the choice affects concurrency, authentication, and deployment.

## Offline mode

Call the service functions directly from the same Julia process that runs the training
code. There is no server to start and no network involved.

```julia
using DearDiary

DearDiary.initialize_database(; file_name="my_project.db")

project_id, _ = create_project("Iris Classifier")
experiment_id, _ = create_experiment(project_id, DearDiary.IN_PROGRESS, "Baseline")

with_iteration(experiment_id) do iter
    create_parameter(iter.id, "lr", 1e-3)
    create_metric(iter.id, "accuracy", 0.94)
end
```

`create_project(name)` uses the seeded `default` user. There is no authentication prompt.
This suits a single training job or notebook session on a laptop.

Offline mode stores metadata in a local DuckDB file (`deardiary.db` by default, overridden
by the `file_name` argument to `initialize_database`). The file is portable: copy it
anywhere that has DearDiary installed to inspect the results.

## Server mode

Run [`DearDiary.run`](@ref) to start the REST API server, then connect to it from a
separate process or machine using the [`Client`](@ref).

```julia
# Process 1: start the server
using DearDiary
DearDiary.run(; env_file=".env")
```

```julia
# Process 2: connect and log
using DearDiary
client = DearDiary.connect("http://127.0.0.1:9000"; username="default", password="default")

project_id, _ = create_project(client, "Iris Classifier")
experiment_id, _ = create_experiment(client, project_id, DearDiary.IN_PROGRESS, "Baseline")

with_iteration(client, experiment_id) do iter
    create_parameter(client, iter.id, "lr", 1e-3)
    create_metric(client, iter.id, "accuracy", 0.94)
end
```

The server injects the authenticated user into each request via `AuthMiddleware`. When
authentication is disabled (`DEARDIARY_ENABLE_AUTH=false`, the default), the `default` user
is implied, matching the offline behaviour.

Multiple training jobs can write to the same server simultaneously. Server mode is
appropriate for scheduled jobs or any setup where more than one process writes tracking data
concurrently.

## Choosing a mode

| | Offline | Server |
|---|---|---|
| Setup | `initialize_database(...)` | `DearDiary.run(...)` |
| Auth | None | Optional JWT |
| Concurrent writers | Single process | Multiple processes |
| Data location | Local DuckDB file | Server-side DuckDB file |

Offline mode is the simpler starting point. Server mode is appropriate when concurrent
writers are required or the tracking store needs to be separated from the training machines.
