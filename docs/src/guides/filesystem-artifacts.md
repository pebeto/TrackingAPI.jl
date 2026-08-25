# Store artifacts on a filesystem

By default, DearDiary stores every [`Resource`](@ref DearDiary.Resource) artifact inline in the database.
That works for kilobyte-sized configs and small serialised models, but a 500 MB checkpoint
will substantially increase the database file size and slow every metadata query. The
[`DearDiary.FilesystemStore`](@ref) backend writes artifact bytes to a directory on local
disk, keeping the database file smaller and allowing the bytes to be backed up along with
the rest of the storage volume.

## Configuration

Set two environment variables in the `.env` file:

```text
DEARDIARY_ARTIFACT_BACKEND=filesystem
DEARDIARY_ARTIFACT_FS_ROOT=/var/lib/deardiary/artifacts
```

The root directory is created on the first write. No separate provisioning step is needed.

## Layout on disk

Each artifact is written to `<root>/<aa>/<uuid>`, where `<aa>` is a two-character shard of
the UUID so no single directory grows unbounded. Two uploads of identical bytes produce
distinct files: there is no content-addressed deduplication, so deleting one
[`Resource`](@ref DearDiary.Resource) cannot break a sibling that uploaded the same payload.

```@setup filesystem-artifacts
using DearDiary
artifact_root = mktempdir()
DearDiary._DEARDIARY_APICONFIG = DearDiary.APIConfig(
    "127.0.0.1", UInt16(0), joinpath(mktempdir(), "deardiary.db"),
    "tutorial-secret", false, ["*"],
    "filesystem", artifact_root,
    "", "", "us-east-1", "", "",
    false, "127.0.0.1", UInt16(0),
)
DearDiary.initialize_database(; file_name=DearDiary._DEARDIARY_APICONFIG.db_file)
```

## End-to-end example

Create a project, experiment, and iteration, then upload an artifact through the configured store:

```@repl filesystem-artifacts
project_id, _ = create_project("Filesystem tutorial");
experiment_id, _ = create_experiment(project_id, DearDiary.IN_PROGRESS, "FS experiment");
iteration_id, _ = create_iteration(experiment_id);
payload = rand(UInt8, 4096);
resource_id, _ = create_resource(experiment_id, "checkpoint.bin", payload);
```

The resource row records the new backend and the URI that points at the bytes on disk:

```@repl filesystem-artifacts
resource = get_resource(resource_id)
```

```@repl filesystem-artifacts
resource.backend
```

```@repl filesystem-artifacts
resource.uri |> startswith("file://")
```

The on-disk path is reachable directly for inspection or streaming from another process. DearDiary itself reads through [`read_resource_data`](@ref):

```@repl filesystem-artifacts
read_resource_data(resource_id) == payload
```

```@setup filesystem-artifacts
DearDiary.close_database()
DearDiary._DEARDIARY_APICONFIG = nothing
```
