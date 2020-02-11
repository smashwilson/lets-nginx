#!/bin/bash

set -euo pipefail

# Validate environment variables

MISSING=""

[ -z "${DOMAIN}" ] && MISSING="${MISSING} DOMAIN"
[ -z "${UPSTREAM}" ] && MISSING="${MISSING} UPSTREAM"


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
      -e "s/\${UPSTREAM}/${UPSTREAM}/" \
      /templates/nginx.conf > "$dest"


# Process templates
upstreamId=0
letscmd=""
for t in "${DOMAINSARRAY[@]}"
do
  dest="/etc/nginx/vhosts/$(basename "${t}").conf"
  src="/templates/vhost.sample.conf"

  if [ -r /configs/"${t}".conf ]; then
    echo "Manual configuration found for $t"
    src="/configs/${t}.conf"
  fi

  echo "Rendering template of $t in $dest"
  sed -e "s/\${DOMAIN}/${t}/g" \
      -e "s/\${UPSTREAM}/${UPSTREAMARRAY[upstreamId]}/" \
      -e "s/\${PATH}/${DOMAINSARRAY[0]}/" \
      "$src" > "$dest"

  upstreamId=$((upstreamId+1))
  certPath=/etc/letsencrypt/live/${DOMAINSARRAY[0]}

  #prepare the letsencrypt command arguments
  letscmd="$letscmd-d $t "
done

# Check if the SAN list has changed
if [ ! -f /etc/letsencrypt/san_list ]; then
 cat <<EOF >/etc/letsencrypt/san_list
 "${DOMAIN}"
EOF
  fresh=true
else
  old_san=$(cat /etc/letsencrypt/san_list)
  if [ "${DOMAIN}" != "${old_san}" ]; then
    fresh=true
  else
    fresh=false
  fi
fi

# Initial certificate request, but skip if cached
if [ $fresh = true ]; then
  echo "The SAN list has changed, removing the old certificates"
  rm -rf /etc/letsencrypt/{live,archive,keys,renewal}
  
  echo "downloading acme.sh"
  curl -sS https://get.acme.sh -o acme.sh
  /bin/bash acme.sh --upgrade --auto-upgrade

  echo "Querying the certificates"
  echo "/root/.acme.sh/acme.sh --issue --standalone \
   "${letscmd}"" > /etc/nginx/lets

  /bin/cat /etc/nginx/lets
  /bin/bash /etc/nginx/lets
  
  #update the stored SAN list
  echo "${DOMAIN}" > /etc/letsencrypt/san_list
  
  echo "Installing the certificates"
  mkdir -p ${certPath}
  echo "/root/.acme.sh/acme.sh --install-cert "${letscmd}" \
    --key-file       ${certPath}/privkey.pem  \
    --fullchain-file ${certPath}/fullchain.pem \
    --reloadcmd     \"/opt/launch_nginx.sh\"" > /tmp/install
  /bin/cat /tmp/install
  /bin/bash /tmp/install
  
fi

# Launch nginx in the foreground
/usr/sbin/nginx -g "daemon off;"
