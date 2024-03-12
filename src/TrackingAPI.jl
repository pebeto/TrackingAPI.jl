module TrackingAPI

using Dates

using HTTP
using Oxygen

include("routes/health.jl")

"""
    run(; host::String="127.0.0.1", port::Int=9000)

Starts the server.

By default, the server will run on `127.0.0.1:9000`. You can change the host
and port by passing the `host` and `port` arguments. 
"""
function run(;
    host::String="127.0.0.1",
    port::Int=9000
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
