@with_deardiary_test_db begin
    @testset verbose = true "auth" begin
        @testset verbose = true "auth handler with user not found" begin
            payload = JSON.json(Dict("username" => "missy", "password" => "gala"))
            response = HTTP.post(
                "http://127.0.0.1:9000/auth"; body=payload, status_exception=false
            )

            @test response.status == HTTP.StatusCodes.NOT_FOUND
        end

        @testset verbose = true "auth handler with invalid credentials" begin
            payload = JSON.json(Dict("username" => "default", "password" => "gala"))
            response = HTTP.post(
                "http://127.0.0.1:9000/auth"; body=payload, status_exception=false
            )

            @test response.status == HTTP.StatusCodes.UNAUTHORIZED
        end

        @testset verbose = true "auth handler with valid credentials" begin
            payload = JSON.json(Dict("username" => "default", "password" => "default"))
            response = HTTP.post(
                "http://127.0.0.1:9000/auth"; body=payload, status_exception=false
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["token_type"] == "Bearer"
            @test data["access_token"] isa String
            @test data["expires_at"] isa Int
            @test data["user"]["username"] == "default"
            @test !haskey(data["user"], "password")
        end

        @testset verbose = true "GET /auth/me" begin
            payload = JSON.json(Dict("username" => "default", "password" => "default"))
            login = HTTP.post(
                "http://127.0.0.1:9000/auth"; body=payload, status_exception=false
            )
            token = JSON.parse(String(login.body), Dict{String,Any})["access_token"]

            response = HTTP.get(
                "http://127.0.0.1:9000/auth/me";
                headers=Dict("Authorization" => "Bearer $token"),
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["username"] == "default"
            @test data["is_admin"] == true
            @test !haskey(data, "password")
        end

        @testset verbose = true "GET /auth/me without token" begin
            response = HTTP.get("http://127.0.0.1:9000/auth/me"; status_exception=false)
            @test response.status == HTTP.StatusCodes.UNAUTHORIZED
        end

        @testset verbose = true "POST /auth/refresh with valid token" begin
            login = HTTP.post(
                "http://127.0.0.1:9000/auth";
                body=(JSON.json(Dict("username" => "default", "password" => "default"))),
                status_exception=false,
            )
            login_data = JSON.parse(String(login.body), Dict{String,Any})
            token = login_data["access_token"]

            response = HTTP.post(
                "http://127.0.0.1:9000/auth/refresh";
                headers=Dict("Authorization" => "Bearer $token"),
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["access_token"] isa String
            @test data["token_type"] == "Bearer"
            @test data["expires_at"] isa Int
            @test data["user"]["username"] == "default"
            @test !haskey(data["user"], "password")
            @test data["expires_at"] >= login_data["expires_at"]
        end

        @testset verbose = true "POST /auth/refresh without token" begin
            response = HTTP.post(
                "http://127.0.0.1:9000/auth/refresh"; status_exception=false
            )
            @test response.status == HTTP.StatusCodes.UNAUTHORIZED
        end

        @testset verbose = true "error responses carry stable code" begin
            @testset "TOKEN_MISSING" begin
                response = HTTP.get("http://127.0.0.1:9000/user/1"; status_exception=false)
                @test response.status == HTTP.StatusCodes.UNAUTHORIZED
                data = JSON.parse(String(response.body), Dict{String,Any})
                @test data["code"] == "TOKEN_MISSING"
                @test !isempty(data["message"])
            end

            @testset "TOKEN_INVALID" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer not.a.token"),
                    status_exception=false,
                )
                data = JSON.parse(String(response.body), Dict{String,Any})
                @test data["code"] == "TOKEN_INVALID"
            end

            @testset "TOKEN_EXPIRED" begin
                claims = Dict(
                    "sub" => "default",
                    "id" => 1,
                    "exp" => Int((floor(datetime2unix((now() - Hour(1)))))),
                )
                jwt = JWT(; payload=claims)
                key = JWKSymmetric(
                    "HS256",
                    Array{UInt8,1}(DearDiary._DEARDIARY_APICONFIG.jwt_secret),
                )
                sign!(jwt, key)
                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $(jwt |> string)"),
                    status_exception=false,
                )
                data = JSON.parse(String(response.body), Dict{String,Any})
                @test data["code"] == "TOKEN_EXPIRED"
            end

            @testset "TOKEN_PAYLOAD_INVALID" begin
                jwt = JWT(; payload=Dict())
                key = JWKSymmetric(
                    "HS256",
                    Array{UInt8,1}(DearDiary._DEARDIARY_APICONFIG.jwt_secret),
                )
                sign!(jwt, key)
                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $(jwt |> string)"),
                    status_exception=false,
                )
                data = JSON.parse(String(response.body), Dict{String,Any})
                @test data["code"] == "TOKEN_PAYLOAD_INVALID"
            end

            @testset "USER_NOT_FOUND on login" begin
                response = HTTP.post(
                    "http://127.0.0.1:9000/auth";
                    body=(JSON.json(Dict("username" => "ghost", "password" => "x"))),
                    status_exception=false,
                )
                data = JSON.parse(String(response.body), Dict{String,Any})
                @test data["code"] == "USER_NOT_FOUND"
            end

            @testset "INVALID_CREDENTIALS" begin
                response = HTTP.post(
                    "http://127.0.0.1:9000/auth";
                    body=(JSON.json(Dict("username" => "default", "password" => "wrong"))),
                    status_exception=false,
                )
                data = JSON.parse(String(response.body), Dict{String,Any})
                @test data["code"] == "INVALID_CREDENTIALS"
            end
        end

        @testset verbose = true "POST /auth/refresh with expired token" begin
            claims = Dict(
                "sub" => "default",
                "id" => 1,
                "exp" => Int((floor(datetime2unix((now() - Hour(1)))))),
            )
            jwt = JWT(; payload=claims)
            key = JWKSymmetric(
                "HS256", Array{UInt8,1}(DearDiary._DEARDIARY_APICONFIG.jwt_secret)
            )
            sign!(jwt, key)

            response = HTTP.post(
                "http://127.0.0.1:9000/auth/refresh";
                headers=Dict("Authorization" => "Bearer $(jwt |> string)"),
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.UNAUTHORIZED
        end

        @testset verbose = true "issued tokens are valid for ~24h" begin
            login = HTTP.post(
                "http://127.0.0.1:9000/auth";
                body=(JSON.json(Dict("username" => "default", "password" => "default"))),
                status_exception=false,
            )
            data = JSON.parse(String(login.body), Dict{String,Any})
            now_unix = Int((floor((datetime2unix(now())))))
            ttl_seconds = data["expires_at"] - now_unix
            @test ttl_seconds > 23 * 3600
            @test ttl_seconds <= 24 * 3600
        end

        @testset verbose = true "without authorization header" begin
            response = HTTP.get("http://127.0.0.1:9000/user/1"; status_exception=false)

            @test response.status == HTTP.StatusCodes.UNAUTHORIZED
        end

        @testset verbose = true "with authorization header" begin
            @testset "with valid JWT" begin
                payload = JSON.json(Dict("username" => "default", "password" => "default"))
                response = HTTP.post(
                    "http://127.0.0.1:9000/auth"; body=payload, status_exception=false
                )

                login_data = JSON.parse(String(response.body), Dict{String,Any})
                token = login_data["access_token"]
                user_id = login_data["user"]["id"]

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/$user_id";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.OK
            end

            @testset "with invalid JWT validation process" begin
                token = "invalid.token.string"

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.UNAUTHORIZED
                @test contains("Invalid token")(String(response.body))
            end

            @testset "with invalid JWT" begin
                claims = Dict(
                    "sub" => "default",
                    "id" => 1,
                    "exp" => Int((floor(datetime2unix((now() + Hour(1)))))),
                )
                jwt = JWT(; payload=claims)
                key = JWKSymmetric("HS256", Array{UInt8,1}("incorrect secret"))
                sign!(jwt, key)
                token = string(jwt)

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.UNAUTHORIZED
                @test contains("Invalid token")(String(response.body))
            end

            @testset "with valid JWT but empty payload" begin
                jwt = JWT(; payload=Dict())
                key = JWKSymmetric(
                    "HS256",
                    Array{UInt8,1}(DearDiary._DEARDIARY_APICONFIG.jwt_secret),
                )
                sign!(jwt, key)
                token = string(jwt)

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.UNAUTHORIZED
                @test contains("Invalid token payload")(String(response.body))
            end

            @testset "with expired JWT" begin
                claims = Dict(
                    "sub" => "default",
                    "id" => 1,
                    "exp" => Int((floor(datetime2unix((now() - Hour(1)))))),
                )
                jwt = JWT(; payload=claims)
                key = JWKSymmetric(
                    "HS256",
                    Array{UInt8,1}(DearDiary._DEARDIARY_APICONFIG.jwt_secret),
                )
                sign!(jwt, key)
                token = string(jwt)

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.UNAUTHORIZED
                @test contains("Token has expired")(String(response.body))
            end

            @testset "with unknown string id in JWT" begin
                claims = Dict(
                    "sub" => "default",
                    "id" => "one",
                    "exp" => Int((floor(datetime2unix((now() + Hour(1)))))),
                )
                jwt = JWT(; payload=claims)
                key = JWKSymmetric(
                    "HS256",
                    Array{UInt8,1}(DearDiary._DEARDIARY_APICONFIG.jwt_secret),
                )
                sign!(jwt, key)
                token = string(jwt)

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.UNAUTHORIZED
                @test contains("User not found")(String(response.body))
            end

            @testset "with zero as id in JWT" begin
                claims = Dict(
                    "sub" => "default",
                    "id" => 0,
                    "exp" => Int((floor(datetime2unix((now() + Hour(1)))))),
                )
                jwt = JWT(; payload=claims)
                key = JWKSymmetric(
                    "HS256",
                    Array{UInt8,1}(DearDiary._DEARDIARY_APICONFIG.jwt_secret),
                )
                sign!(jwt, key)
                token = string(jwt)

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.UNAUTHORIZED
                @test contains("Invalid token payload")(String(response.body))
            end

            @testset "with non-existing user id in JWT" begin
                claims = Dict(
                    "sub" => "default",
                    "id" => "00000000-0000-0000-0000-000000000000",
                    "exp" => Int((floor(datetime2unix((now() + Hour(1)))))),
                )
                jwt = JWT(; payload=claims)
                key = JWKSymmetric(
                    "HS256",
                    Array{UInt8,1}(DearDiary._DEARDIARY_APICONFIG.jwt_secret),
                )
                sign!(jwt, key)
                token = string(jwt)

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.UNAUTHORIZED
                @test contains("User not found")(String(response.body))
            end
        end
    end
end
