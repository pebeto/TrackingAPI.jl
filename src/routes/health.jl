function get_health()
    app_name = "TrackingAPI"
    package_version = pkgversion(TrackingAPI)
    server_time = Dates.now()

    data = Dict(
        "app_name" => app_name,
        "package_version" => package_version,
        "server_time" => server_time,
    )

    return json(data; status=STATUS_OK)
end
