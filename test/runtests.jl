using HTTP
using JSON
# JWTs 1.0 does not surface its exports through a plain `using`, so import the names the auth
# tests construct tokens with explicitly.
using JWTs: JWT, JWKSymmetric, sign!
using Test
using Dates
using Bcrypt
using Compat
using SHA
using Sockets
using DuckDB
using DBInterface
using Tables

using DearDiary

"""
    create_test_env_file()::String

Create a test environment file for the API server.

# Returns
A string representing the path to the created test environment file.
"""
function create_test_env_file(;
    host::AbstractString="127.0.0.1",
    port::Integer=9000,
    db_file::AbstractString="deardiary_test.db",
    jwt_secret::Union{AbstractString,Nothing}=nothing,
    enable_auth::Bool=false,
    enable_ui::Bool=false,
)::String
    file = ".env.deardiarytest"

    open(file, "w") do io
        write(io, "DEARDIARY_HOST=$host\n")
        write(io, "DEARDIARY_PORT=$port\n")
        write(io, "DEARDIARY_DB_FILE=$db_file\n")
        write(io, "# DEARDIARY_DB_FILE=comment\n")
        if !(isnothing(jwt_secret))
            write(io, "DEARDIARY_JWT_SECRET=$jwt_secret\n")
        end
        write(io, "DEARDIARY_ENABLE_AUTH=$enable_auth\n")
        # Keep the Bonito UI server off in the route tests: booting it renders the dashboard,
        # which bundles JS via a Deno subprocess that hangs on a headless CI runner.
        write(io, "DEARDIARY_ENABLE_UI=$enable_ui\n")
    end
    return file
end

macro with_deardiary_test_db(expr)
    quote
        is_api = !(isnothing(DearDiary._DEARDIARY_APICONFIG))
        if is_api
            DearDiary.initialize_database(;
                file_name=DearDiary._DEARDIARY_APICONFIG.db_file
            )
        else
            DearDiary.initialize_database(; file_name="deardiary_offline_test.db")
        end

        try
            $(esc(expr))
        finally
            if is_api
                DearDiary.close_database()
                rm(DearDiary._DEARDIARY_APICONFIG.db_file)
            else
                DearDiary.close_database()
                rm("deardiary_offline_test.db")
            end
        end
    end
end

include("Aqua.jl")

include("utils.jl")

# Functional tests
include("types/parameter.jl")
include("types/utils.jl")
include("types/enums.jl")

include("artifacts/vectors.jl")
include("artifacts/store.jl")
include("artifacts/filesystem.jl")
include("artifacts/s3.jl")
include("artifacts/migrate.jl")

include("reproducibility/snapshot.jl")

include("repositories/database.jl")
include("repositories/user.jl")
include("repositories/project.jl")
include("repositories/userpermission.jl")
include("repositories/experiment.jl")
include("repositories/iteration.jl")
include("repositories/parameter.jl")
include("repositories/metric.jl")
include("repositories/resource.jl")
include("repositories/tag.jl")
include("repositories/model.jl")
include("repositories/modelversion.jl")
include("repositories/utils.jl")

include("services/user.jl")
include("services/utils.jl")
include("services/project.jl")
include("services/userpermission.jl")
include("services/experiment.jl")
include("services/iteration.jl")
include("services/parameter.jl")
include("services/metric.jl")
include("services/resource.jl")
include("services/tag.jl")
include("services/model.jl")
include("services/modelversion.jl")

include("ui/app.jl")
include("ui/server.jl")

# Auth tests
file = create_test_env_file(; enable_auth=true, jwt_secret="testsecret")
DearDiary.run(; env_file=file)

include("routes/auth.jl")
include("routes/utils.jl")

DearDiary.stop()
rm(file)

# Route tests
file = create_test_env_file()
DearDiary.run(; env_file=file)

include("routes/health.jl")
include("routes/user.jl")
include("routes/project.jl")
include("routes/userpermission.jl")
include("routes/experiment.jl")
include("routes/iteration.jl")
include("routes/parameter.jl")
include("routes/metric.jl")
include("routes/resource.jl")
include("routes/tag.jl")
include("routes/model.jl")
include("routes/modelversion.jl")

include("client/client.jl")

DearDiary.stop()
rm(file)
