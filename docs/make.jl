using Pkg
# Pin the docs environment to the local DearDiary checkout. Without this the docs/
# Manifest can pin a stale registered version (the bug that surfaced as a wall of
# "undefined binding" errors against symbols added since the last release), and
# `julia --project=docs docs/make.jl` diverges from what the CI workflow does.
Pkg.develop(PackageSpec(; path=dirname(@__DIR__)))
Pkg.instantiate()

using Documenter
using DearDiary

DocMeta.setdocmeta!(DearDiary, :DocTestSetup, :(using DearDiary); recursive=true)

makedocs(;
    modules=[DearDiary],
    sitename="$(DearDiary |> nameof |> String).jl",
    format=Documenter.HTML(;),
    pages=[
        "Home" => "index.md",
        "Getting started" => [
            "Installation" => "getting-started/installation.md",
            "Quickstart" => "getting-started/quickstart.md",
        ],
        "Concepts" => [
            "Data model" => "concepts/data-model.md",
            "Offline vs server" => "concepts/usage-modes.md",
            "Storage backends" => "concepts/storage.md",
            "Reproducibility" => "concepts/reproducibility.md",
        ],
        "Guides" => [
            "Log from a remote client" => "guides/remote-client.md",
            "Store artifacts on a filesystem" => "guides/filesystem-artifacts.md",
            "Store artifacts on S3" => "guides/s3-artifacts.md",
            "Register and stage models" => "guides/model-registry.md",
            "Parent and child iterations" => "guides/child-iterations.md",
            "Reproduce a past run" => "guides/reproduce-a-run.md",
            "Migrate artifacts" => "guides/migrate-artifacts.md",
        ],
        "Running the server" => [
            "Configuration" => "server/configuration.md",
            "Authentication" => "server/authentication.md",
            "Embedded web UI" => "server/web-ui.md",
        ],
        "Reference" => [
            "Tracking API" => "reference/tracking.md",
            "Logged data" => "reference/logged-data.md",
            "Users and permissions" => "reference/users-and-permissions.md",
            "Model registry" => "reference/model-registry.md",
            "Artifact storage" => "reference/artifacts.md",
            "Reproducibility" => "reference/reproducibility.md",
            "Client and REST API" => "reference/client-and-rest.md",
            "Types and internals" => "reference/types.md",
            "Migrations" => "reference/migrations.md",
            "Symbol index" => "reference/index.md",
        ],
    ],
    warnonly=[:cross_references, :missing_docs],
)

deploydocs(; repo="github.com/JuliaAI/DearDiary.jl.git", devbranch="dev")
