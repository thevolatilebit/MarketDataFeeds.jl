"Evaluate the content of `file`."
macro read(file)
    Meta.parse(read(file, String)) |> esc
end

"Create a nginx proxy server configuration file. Listen at localhost's `listen` port."
function make_proxy(; IBKR="https://localhost:5050", 
    listen="5051", burst=5, crt="cert.crt", key=".key")

    # API endpoints: batch definition
    endpoints = include("endpoints.jl")

    header = """
        load_module modules/ngx_http_js_module.so;

        events {}
        http {
            log_format log_format '\$remote_addr - \$remote_user [\$time_local] '
                        '"\$request" \$status \$body_bytes_sent '
                        '"\$http_referer" "\$http_user_agent" "\$gzip_ratio"';
    """

    server = """
        server {
            js_import json_validation.js;
            js_set \$limit_body json_validation.limit_body;

            listen $listen ssl;
            ssl_certificate $crt;
            ssl_certificate_key $key;

            access_log logs/access.log log_format;
            error_log logs/error.log crit;
    """

    limit_zones = ["limit_req_zone global0 zone=global0:10m rate=10r/s;"]

    n_zones = 1

    locations = @read "extra_locations.jl"

    for endpoint in endpoints
        if endpoint isa Tuple
            location, limit = endpoint
            # new limit zone
            push!(limit_zones, "limit_req_zone global$n_zones zone=global$n_zones:10m rate=$limit;")
            # create location
            push!(locations, """
            location $location {
                limit_req zone=global0 burst=$burst;
                limit_req zone=global$n_zones burst=$burst;
                limit_req_status 429;

                proxy_pass $IBKR$location;
            }""")

            n_zones += 1
        else
            location = endpoint
            push!(locations, """
            location $location {
                limit_req zone=global0 burst=$burst;
                limit_req_status 429;

                proxy_pass $IBKR$location;
            }""")
        end
    end

    config = header * "\n"  * join(limit_zones, "\n") * "\n" * server * "\n" * join(locations, "\n") * "\n" * "\n}\n}"

    write("ibkr-proxy/server.conf", config)
end