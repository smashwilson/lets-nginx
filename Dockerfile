FROM alpine:3.2
MAINTAINER Ash Wilson <smashwilson@gmail.com>

RUN apk add --update nginx \
  python python-dev py-pip \
  gcc musl-dev linux-headers \
  augeas-dev openssl-dev libffi-dev ca-certificates dialog \
  && rm -rf /var/cache/apk/*

RUN pip install -U letsencrypt

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

ADD reissue.sh /etc/periodic/15min/reissue.sh
ADD entrypoint.sh /entrypoint.sh

EXPOSE 80 443

ENTRYPOINT ["/entrypoint.sh"]
