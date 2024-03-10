using Documenter
using TrackingAPI

DocMeta.setdocmeta!(TrackingAPI, :DocTestSetup, :(using TrackingAPI); recursive=true)

makedocs(;
    modules=[TrackingAPI],
    sitename="TrackingAPI.jl",
    format=Documenter.HTML(;),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/pebeto/TrackingAPI.jl.git",
)
