#!/bin/sh

# Validate environment variables

MISSING=""

[ -z "${DOMAIN}" ] && MISSING="${MISSING} DOMAIN"
[ -z "${UPSTREAM}" ] && MISSING="${MISSING} UPSTREAM"
[ -z "${EMAIL}" ] && MISSING="${MISSING} EMAIL"

if [ "${MISSING}" != "" ]; then
  echo "Missing required environment variables:" >&2
  echo " ${MISSING}" >&2
  exit 1
fi

# Generate strong DH parameters for nginx, if they don't already exist.
[ -f /etc/ssl/dhparams.pem ] || openssl dhparam -out /etc/ssl/dhparams.pem 2048

# Template an nginx.conf
cat <<EOF >/etc/nginx/nginx.conf
user nobody;
worker_processes 2;

events {
  worker_connections 1024;
}

http {
  include mime.types;
  default_type application/octet-stream;

  sendfile on;
  tcp_nopush on;
  keepalive_timeout 65;

  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;

  server {
    listen 443 ssl;
    server_name "";

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_dhparam /etc/ssl/dhparams.pem;

    ssl_ciphers "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA";
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;

    location / {
      proxy_pass http://${UPSTREAM};
      proxy_set_header Host \$host;
      proxy_set_header X-Forwarded-For \$remote_addr;
      proxy_read_timeout 120s;
      proxy_send_timeout 120s;
    }
  }
}
EOF

# Initial certificate request
letsencrypt certonly \
  --domain ${DOMAIN} \
  --authenticator standalone \
  --email "${EMAIL}" --agree-tos

# Kick off cron to reissue certificates as required
/usr/sbin/crond &

# Launch nginx in the foreground
/usr/sbin/nginx -g "daemon off;"
