const TOKEN_TTL_HOURS = 24

"""
    issue_token(user::User)::Dict{String,Any}

Mint a fresh JWT for `user` and assemble the standard auth response envelope.

# Arguments
- `user::User`: The authenticated user the token represents.

# Returns
A `Dict` with `access_token`, `token_type`, `expires_at` (Unix epoch seconds), and a
sanitized `user` payload, matching the shape returned by `POST /auth` and `POST /auth/refresh`.
"""
function issue_token(user::User)::Dict{String,Any}
    global _DEARDIARY_APICONFIG
    expires_at = Int((floor(datetime2unix((now() + Hour(TOKEN_TTL_HOURS))))))
    claims = Dict("sub" => user.username, "id" => user.id, "exp" => expires_at)
    jwt = JWT(; payload=claims)
    key = JWKSymmetric("HS256", Array{UInt8,1}(_DEARDIARY_APICONFIG.jwt_secret))
    sign!(jwt, key)
    return Dict{String,Any}(
        "access_token" => (string(jwt)),
        "token_type" => "Bearer",
        "expires_at" => expires_at,
        "user" => (sanitize_user(user)),
    )
end

"""
    setup_auth_routes()

Register authentication routes (`/auth`). Internal use only.
"""
function setup_auth_routes()
    root = router("/auth"; tags=["auth"])

    @get root("/me") function (request::HTTP.Request)
        global _DEARDIARY_APICONFIG
        if !_DEARDIARY_APICONFIG.enable_auth
            request.context[:user] = get(
                request.context, :user, get_user_by_username("default")
            )
        end
        return json((sanitize_user(request.context[:user])); status=HTTP.StatusCodes.OK)
    end

    @post root("/") function (::HTTP.Request, parameters::Json{UserLoginPayload})
        user = get_user_by_username(parameters.payload.username)

        if isnothing(user)
            return error_response(
                UserNotFound, "User not found"; status=HTTP.StatusCodes.NOT_FOUND
            )
        end

        if !CompareHashAndPassword(user.password, parameters.payload.password)
            return error_response(
                InvalidCredentials,
                "Invalid credentials";
                status=HTTP.StatusCodes.UNAUTHORIZED,
            )
        end

        return json(issue_token(user); status=HTTP.StatusCodes.OK)
    end

    @post root("/refresh") function (request::HTTP.Request)
        global _DEARDIARY_APICONFIG
        user = if _DEARDIARY_APICONFIG.enable_auth
            request.context[:user]
        else
            get(request.context, :user, get_user_by_username("default"))
        end
        return json(issue_token(user); status=HTTP.StatusCodes.OK)
    end
end
