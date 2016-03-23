#!/bin/bash

set -euo pipefail

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

#Processing DOMAIN into an array
DOMAINSARRAY=($(echo "${DOMAIN}" | awk -F ";" '{for(i=1;i<=NF;i++) print $i;}'))
echo "Provided domains"
printf "%s\n" "${DOMAINSARRAY[@]}"
  
#Processing UPSTREAM into an array
UPSTREAMARRAY=($(echo "${UPSTREAM}" | awk -F ";" '{for(i=1;i<=NF;i++) print $i;}'))
echo "Services to reverse-proxy"
printf "%s\n" "${UPSTREAMARRAY[@]}"

#The two arrays should have the same lenght
if [ "${#DOMAINSARRAY[@]}" != "${#UPSTREAMARRAY[@]}" ]; then
  echo "The number of domains must match the number of upstream services"
fi

# Default other parameters

SERVER=""
[ -n "${STAGING:-}" ] && SERVER="--server https://acme-staging.api.letsencrypt.org/directory"

# Generate strong DH parameters for nginx, if they don't already exist.
if [ ! -f /etc/ssl/dhparams.pem ]; then
  if [ -f /cache/dhparams.pem ]; then
    cp /cache/dhparams.pem /etc/ssl/dhparams.pem
  else
    openssl dhparam -out /etc/ssl/dhparams.pem 2048
    # Cache to a volume for next time?
    if [ -d /cache ]; then
      cp /etc/ssl/dhparams.pem /cache/dhparams.pem
    fi
  fi
fi

#create temp file storage
mkdir -p /var/cache/nginx
chown nginx:nginx /var/cache/nginx

mkdir -p /var/tmp/nginx
chown nginx:nginx /var/tmp/nginx

#create vhost directory
mkdir -p /etc/nginx/vhosts/

# Process the nginx.conf with raw values of $DOMAIN and $UPSTREAM to ensure backward-compatibility
  dest="/etc/nginx/nginx.conf"
  echo "Rendering template of nginx.conf"
  sed -e "s/\${DOMAIN}/${DOMAIN}/g" \
      -e "s/\${UPSTREAM}/${DOMAIN}/" \
      /templates/nginx.conf > "$dest"


# Process templates
upstreamId=0
letscmd=""
for t in "${DOMAINSARRAY[@]}"
do
  dest="/etc/nginx/vhosts/$(basename "${t}").conf"
  echo "Rendering template of $t in $dest"
  sed -e "s/\${DOMAIN}/${t}/g" \
      -e "s/\${UPSTREAM}/${UPSTREAMARRAY[upstreamId]}/" \
      /templates/vhost.sample.conf > "$dest"
  upstreamId=$((upstreamId+1))

  # prepare the letsencrypt command arguments, but skip if cached
  if [ ! -f /etc/letsencrypt/live/"${t}"/fullchain.pem ]; then
    letscmd="$letscmd --domain $t "
  fi
done

if ! [ -z "$letscmd" ]; then
  letsencrypt certonly \
    ${letscmd} \
    --standalone \
    --email "${EMAIL}" --agree-tos
fi

# Template a cronjob to reissue the certificate with the webroot authenticator
cat <<EOF >/etc/periodic/monthly/reissue
  #!/bin/sh

  set -euo pipefail

  # Certificate reissue
  letsencrypt certonly --force-renewal \
    --webroot \
    -w /etc/letsencrypt/webrootauth/ \
    ${letscmd} \
    --email "${EMAIL}" --agree-tos

  # Reload nginx configuration to pick up the reissued certificates
  /usr/sbin/nginx -s reload
EOF

chmod +x /etc/periodic/monthly/reissue

# Kick off cron to reissue certificates as required
# Background the process and log to stderr
/usr/sbin/crond -f -d 8 &

echo Ready
# Launch nginx in the foreground
/usr/sbin/nginx -g "daemon off;"
