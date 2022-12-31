["""
    location /_get_request_body {
        return 204;
    }

    location /trsv/secdef {
        set \$upstream $IBKR/trsv/secdef;
        limit_req zone=global0 burst=$burst;
        mirror /_get_request_body;
        client_body_in_single_buffer on;
        client_body_buffer_size 16k;                        
        limit_req_status 429;

        proxy_pass \$limit_body;
    }""",
    """
    location /v1/api/ws {
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade"; 
        proxy_pass $IBKR/v1/api/ws;
    }"""
]