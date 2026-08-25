# Authentication

## Auth disabled (default)

`DEARDIARY_ENABLE_AUTH` defaults to `false`. In this mode the server's
`AuthMiddleware` does not inspect any token. Every request is processed as the
seeded `default` admin user. No credentials are needed.

Connect without a username or password:

```julia
client = connect("http://127.0.0.1:9000")
```

## Enabling auth

Set `DEARDIARY_ENABLE_AUTH=true` in the env file and restart the server. All routes
except `POST /auth` and `GET /health` require a valid `Authorization: Bearer <token>`
header. Starting the server with auth enabled and the default `DEARDIARY_JWT_SECRET`
raises an error: set a strong, unique secret first.

## Token flow

**Sign in:** `POST /auth` with a JSON body:

```json
{ "username": "alice", "password": "secret" }
```

The response envelope:

```json
{
  "access_token": "<jwt>",
  "token_type": "Bearer",
  "expires_at": 1234567890,
  "user": { "id": "8f14e45f-ceea-467a-9c1e-1b1f9c0d3a52", "username": "alice", "is_admin": false, ... }
}
```

Tokens expire after 24 hours.

**Authorize requests:** attach the token to every request:

```
Authorization: Bearer <token>
```

**Refresh:** `POST /auth/refresh` with a valid (non-expired) token. Returns the
same envelope shape with a fresh token and a new `expires_at`.

## Client helpers

[`connect`](@ref) handles the sign-in call and stores the returned token:

```julia
client = connect("http://127.0.0.1:9000"; username="alice", password="secret")
```

Pass an already-issued token instead:

```julia
client = connect("http://127.0.0.1:9000"; token="<jwt>")
```

[`whoami`](@ref) returns the user behind the current token and refreshes the
cached `client.user`:

```julia
user = whoami(client)
```

[`refresh_token!`](@ref) calls `POST /auth/refresh` and updates `client.token` in
place:

```julia
refresh_token!(client)
```

## Privilege rules

The `is_admin` field on a user record is a privilege boundary. A non-admin user
can update their own account (name, password) but cannot set the `is_admin` flag on
any account. Only a user with `is_admin = true` may promote or demote a user.
Attempting to set `is_admin` without admin privileges returns `403 Forbidden`.
