FROM nginx:alpine
MAINTAINER Ash Wilson <smashwilson@gmail.com>

#We need to install bash to easily handle arrays
# in the entrypoint.sh script
RUN apk add --update bash \
  curl \
  socat \
  openssl openssl-dev ca-certificates \
  && rm -rf /var/cache/apk/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

# used for webroot reauth
RUN mkdir -p /etc/letsencrypt/webrootauth

COPY entrypoint.sh /opt/entrypoint.sh
ADD templates /templates

# There is an expose in nginx:alpine image
# EXPOSE 80 443

ENTRYPOINT ["/opt/entrypoint.sh"]
