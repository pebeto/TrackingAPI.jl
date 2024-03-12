@testset "health" begin
    response = HTTP.get("http://127.0.0.1:19000/health")

    @assert response.status == HTTP.StatusCodes.OK

    data = response.body |> String |> JSON.parse
    data_keys = keys(data)

    @assert "app_name" in data_keys
    @assert "package_version" in data_keys
    @assert "server_time" in data_keys

    @assert data["app_name"] == "TrackingAPI"
    @assert (data["package_version"] |> VersionNumber) == pkgversion(TrackingAPI)
end
