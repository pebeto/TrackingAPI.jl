module DearDiary

using Oxygen: headers
using HTTP
using JSON
# JWTs 1.0 ships its exports in a way that `using JWTs` does not bring them into scope, so import
# the names this package uses explicitly.
using JWTs: JWT, JWKSymmetric, sign!, validate!, isvalid, claims
using Dates
using Bcrypt
using Bonito
using Compat
using Observables
using Oxygen
using LibGit2
using Pkg
using PrecompileTools: @setup_workload, @compile_workload
using SHA
using DuckDB
using DBInterface
using Tables
using UUIDs

include("utils.jl")

include("types/config.jl")
include("types/enums.jl")
include("types/utils.jl")
include("types/error.jl")
include("types/user.jl")
include("types/project.jl")
include("types/userpermission.jl")
include("types/experiment.jl")
include("types/iteration.jl")
include("types/parameter.jl")
include("types/metric.jl")
include("types/resource.jl")
include("types/tag.jl")
include("types/model.jl")
include("types/modelversion.jl")

include("artifacts/store.jl")
include("artifacts/inline.jl")
include("artifacts/filesystem.jl")
include("artifacts/s3.jl")
include("artifacts/migrate.jl")

include("reproducibility/snapshot.jl")

include("repositories/sql/database.jl")
include("repositories/sql/user.jl")
include("repositories/sql/project.jl")
include("repositories/sql/userpermission.jl")
include("repositories/sql/experiment.jl")
include("repositories/sql/iteration.jl")
include("repositories/sql/parameter.jl")
include("repositories/sql/metric.jl")
include("repositories/sql/resource.jl")
include("repositories/sql/tag.jl")
include("repositories/sql/model.jl")
include("repositories/sql/modelversion.jl")
include("repositories/sql/migrations.jl")

include("repositories/utils.jl")
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

include("services/utils.jl")
include("services/user.jl")
include("services/project.jl")
include("services/userpermission.jl")
include("services/experiment.jl")
include("services/iteration.jl")
include("reproducibility/restore.jl")
include("services/parameter.jl")
include("services/metric.jl")
include("services/resource.jl")
include("services/tag.jl")
include("services/model.jl")
include("services/modelversion.jl")

include("routes/utils.jl")
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
include("routes/auth.jl")

include("client/types.jl")
include("client/http.jl")
include("client/auth.jl")
include("client/user.jl")
include("client/project.jl")
include("client/userpermission.jl")
include("client/experiment.jl")
include("client/iteration.jl")
include("client/parameter.jl")
include("client/metric.jl")
include("client/resource.jl")
include("client/tag.jl")
include("client/model.jl")
include("client/modelversion.jl")
include("client/lifecycle.jl")

include("ui/app.jl")
include("ui/server.jl")

export Client, ClientError, connect, disconnect, refresh_token!, whoami, with_iteration

export get_user,
    get_user_by_username, get_users, create_user, update_user, delete_user, sanitize_user
export get_project, get_projects, create_project, update_project, delete_project
export get_userpermission,
    get_userpermissions, create_userpermission, update_userpermission, delete_userpermission
export get_experiment,
    get_experiments, create_experiment, update_experiment, delete_experiment
export get_iteration, get_iterations, create_iteration, update_iteration, delete_iteration
export get_child_iterations
export snapshot_environment!, capture_environment, restore
export EnvironmentSnapshot, RestoreResult
export get_parameter, get_parameters, create_parameter, update_parameter, delete_parameter
export get_metric, get_metrics, create_metric, update_metric, delete_metric, log_metrics
export get_resource, get_resources, create_resource, update_resource, delete_resource
export read_resource_data
export migrate_artifacts!, MigrateArtifactsResult
export get_tag, get_tag_by_value, get_tags, create_tag, add_tag, delete_tag
export get_model, get_models, create_model, update_model, delete_model
export get_modelversion,
    get_modelversions, create_modelversion, update_modelversion, delete_modelversion

_DEARDIARY_APICONFIG = nothing
# `run` only assigns the UI server when the UI is enabled. Give it a defined default so
# `stop` (which reads it unconditionally) does not error when the UI is disabled.
_DEARDIARY_UI_SERVER = nothing

function AuthMiddleware(handler)
    return function (request::HTTP.Request)
        global _DEARDIARY_APICONFIG

        if _DEARDIARY_APICONFIG.enable_auth
            is_login_route =
                request.target in ("/auth", "/auth/") && request.method == "POST"
            is_health_route =
                startswith("/health")(request.target) && request.method == "GET"

            if !(is_login_route || is_health_route)
                auth_header = get(Dict(request.headers), "Authorization", missing)

                if ismissing(auth_header)
                    return error_response(
                        TokenMissing,
                        "Missing authorization header";
                        status=HTTP.StatusCodes.UNAUTHORIZED,
                    )
                end

                token = string(split(auth_header, " ")[2])
                jwt = JWT(; jwt=token)
                key = JWKSymmetric(
                    "HS256", Array{UInt8,1}(_DEARDIARY_APICONFIG.jwt_secret)
                )
                try
                    validate!(jwt, key)
                catch _
                    return error_response(
                        TokenInvalid, "Invalid token"; status=HTTP.StatusCodes.UNAUTHORIZED
                    )
                end

                if isvalid(jwt)
                    payload = claims(jwt)

                    if isnothing(payload)
                        return error_response(
                            TokenPayloadInvalid,
                            "Invalid token payload";
                            status=HTTP.StatusCodes.UNAUTHORIZED,
                        )
                    end

                    is_valid_payload = all(
                        claim -> haskey(payload, claim), ["sub", "id", "exp"]
                    )
                    if !is_valid_payload
                        return error_response(
                            TokenPayloadInvalid,
                            "Invalid token payload";
                            status=HTTP.StatusCodes.UNAUTHORIZED,
                        )
                    end

                    exp = get(payload, "exp", nothing)
                    now_unix = Int((floor(datetime2unix(now()))))
                    if isnothing(exp) || (exp isa Integer && exp < now_unix)
                        return error_response(
                            TokenExpired,
                            "Token has expired";
                            status=HTTP.StatusCodes.UNAUTHORIZED,
                        )
                    end

                    user_id = get(payload, "id", nothing)
                    is_valid_user_id = user_id isa AbstractString && !isempty(user_id)
                    if !is_valid_user_id
                        return error_response(
                            TokenPayloadInvalid,
                            "Invalid token payload";
                            status=HTTP.StatusCodes.UNAUTHORIZED,
                        )
                    end

                    user = get_user(user_id)
                    if isnothing(user)
                        return error_response(
                            UserNotFound,
                            "User not found";
                            status=HTTP.StatusCodes.UNAUTHORIZED,
                        )
                    end
                    request.context[:user] = user
                else
                    return error_response(
                        TokenInvalid, "Invalid token"; status=HTTP.StatusCodes.UNAUTHORIZED
                    )
                end
            end
        end
        return handler(request)
    end
end

"""
    run(; env_file::String=".env")

Start the server. Reads configuration from `env_file` (defaults to `.env`). The server
binds to `127.0.0.1:9000` unless overridden by `DEARDIARY_HOST` and `DEARDIARY_PORT`.
"""
function run(; env_file::String=".env")
    global _DEARDIARY_APICONFIG = load_config(env_file)

    if _DEARDIARY_APICONFIG.enable_auth &&
        _DEARDIARY_APICONFIG.jwt_secret == "deardiary_secret"
        throw(
            ArgumentError(
                "Authentication is enabled but DEARDIARY_JWT_SECRET is set to the " *
                "built-in default. Set a strong, unique secret via the " *
                "DEARDIARY_JWT_SECRET environment variable before starting the server.",
            ),
        )
    end

    initialize_database(; file_name=_DEARDIARY_APICONFIG.db_file)

    @get "/health" function (::HTTP.Request)
        data = Dict(
            "app_name" => String(nameof(DearDiary)),
            "package_version" => pkgversion(DearDiary),
            "server_time" => Dates.now(),
        )
        return json(data; status=HTTP.StatusCodes.OK)
    end

    setup_user_routes()
    setup_project_routes()
    setup_userpermission_routes()
    setup_experiment_routes()
    setup_iteration_routes()
    setup_parameter_routes()
    setup_metric_routes()
    setup_resource_routes()
    setup_tag_routes()
    setup_model_routes()
    setup_modelversion_routes()
    setup_auth_routes()

    cors = Cors(;
        allowed_origins=_DEARDIARY_APICONFIG.cors_origins,
        allowed_headers=["Authorization", "Content-Type"],
        allowed_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allow_credentials=(!("*" in _DEARDIARY_APICONFIG.cors_origins)),
        max_age=600,
    )
    serveparallel(;
        host=_DEARDIARY_APICONFIG.host,
        port=_DEARDIARY_APICONFIG.port,
        async=true,
        middleware=[cors, AuthMiddleware],
    )
    @info "DearDiary server running on $(_DEARDIARY_APICONFIG.host):$(_DEARDIARY_APICONFIG.port)"

    if _DEARDIARY_APICONFIG.enable_ui
        global _DEARDIARY_UI_SERVER = start_ui_server(
            _DEARDIARY_APICONFIG.ui_host, _DEARDIARY_APICONFIG.ui_port
        )
    end
end

"""
    stop()

Stops the server. Alias for `Oxygen.Core.terminate()`.
"""
function stop()
    global _DEARDIARY_UI_SERVER
    stop_ui_server(_DEARDIARY_UI_SERVER)
    _DEARDIARY_UI_SERVER = nothing

    close_database()
    _DEARDIARY_APICONFIG = nothing

    terminate()
    @info "DearDiary server stopped."
end

end
