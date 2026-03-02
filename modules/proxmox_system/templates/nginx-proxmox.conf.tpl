upstream proxmox_backend {
    server 127.0.0.1:8006;
}

server {
    listen 80;
    listen [::]:80;
    server_name proxmox.${domain};
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name proxmox.${domain};

    ssl_certificate     /etc/ssl/certs/proxmox-acme.pem;
    ssl_certificate_key /etc/ssl/private/proxmox-acme.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    proxy_redirect off;

    location / {
        proxy_pass         https://proxmox_backend;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade        $http_upgrade;
        proxy_set_header   Connection     "upgrade";
        proxy_set_header   Host           $host;
        proxy_set_header   X-Real-IP      $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_buffering    off;
        client_max_body_size 0;
        proxy_connect_timeout  3600s;
        proxy_read_timeout     3600s;
        proxy_send_timeout     3600s;
        send_timeout           3600s;
    }
}
