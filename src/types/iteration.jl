"""
    Iteration <: ResultType

A struct representing an iteration within an experiment.

Fields
- `id::String`: The unique identifier of the iteration.
- `experiment_id::String`: The identifier of the experiment to which the iteration belongs.
- `notes::String`: Notes associated with the iteration.
- `created_date::DateTime`: The date and time when the iteration was created.
- `end_date::Optional{DateTime}`: The date and time when the iteration ended, or `nothing`
  if it is still ongoing.
- `parent_iteration_id::Optional{String}`: The identifier of the parent [`Iteration`](@ref)
  when this iteration is a child run (e.g. one trial in an HPO sweep, one fold in a nested
  CV, one worker in a distributed run). `nothing` for top-level iterations.
- `status_id::Int64`: The current lifecycle [`IterationStatus`](@ref). `RUNNING` while the
  iteration is in flight, then `SUCCEEDED`, `FAILED`, or `KILLED` once it terminates.
- `error_message::String`: Captured exception text when `status_id` is `FAILED`. Empty
  otherwise.
- `julia_version::String`: `string(VERSION)` captured by [`snapshot_environment!`](@ref).
  Empty when no snapshot has been taken.
- `git_sha::String`: HEAD commit SHA captured by [`snapshot_environment!`](@ref). Empty
  when the iteration ran outside a git working tree or no snapshot was taken.
- `git_dirty::Bool`: `true` when the working tree had uncommitted changes at snapshot time.
- `entrypoint::String`: `PROGRAM_FILE` captured by [`snapshot_environment!`](@ref). Empty
  for REPL-driven runs.
- `project_toml::String`: Verbatim contents of the active `Project.toml` at snapshot time.
- `manifest_toml::String`: Verbatim contents of the active `Manifest.toml` at snapshot time,
  the pinned dependency tree that [`restore`](@ref) reconstructs.
"""
struct Iteration <: ResultType
    id::String
    experiment_id::String
    notes::String
    created_date::DateTime
    end_date::Optional{DateTime}
    parent_iteration_id::Optional{String}
    status_id::Int64
    error_message::String
    julia_version::String
    git_sha::String
    git_dirty::Bool
    entrypoint::String
    project_toml::String
    manifest_toml::String
end

struct IterationUpdatePayload <: UpsertType
    notes::Optional{String}
    end_date::Optional{DateTime}
    status_id::Optional{Int64}
    error_message::Optional{String}
end

"""
    IterationSnapshotPayload <: UpsertType

Wire format for the snapshot route. Every field is captured locally by the client (since
`LibGit2` and `Pkg` operate on the calling process's working tree) and posted to the server
to be persisted on the iteration row.
"""
struct IterationSnapshotPayload <: UpsertType
    julia_version::String
    git_sha::String
    git_dirty::Bool
    entrypoint::String
    project_toml::String
    manifest_toml::String
end
