module TrackingAPI

using Dates

using HTTP
using Oxygen

include("constants.jl")
include("routes/health.jl")

"""
    run(; host::String="127.0.0.1", port::Int=8080)

Starts the server.

By default, the server will run on `127.0.0.1:8080`. You can change the host
and port by passing the `host` and `port` arguments. 
"""
function run(;
    host::String="127.0.0.1",
    port::Int=8080
)
    health_router = router("/health", tags=["health"])

    @get health_router("/") get_health

    serveparallel(;
        host=host,
        port=port,
        async=true,
    )
end

"""
    stop()

Stops the server. Alias for `Oxygen.Core.terminate()`.
"""
stop() = terminate()

end
