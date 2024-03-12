using Compat
using HTTP
using JSON
using Test

using TrackingAPI

TrackingAPI.run(; port=19000)

include("routes/health.jl")

TrackingAPI.stop()
