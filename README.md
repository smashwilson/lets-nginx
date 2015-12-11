# Let's Nginx

*[dockerhub build](https://hub.docker.com/r/smashwilson/lets-nginx/)*

Put browser-valid TLS termination in front of any Dockerized HTTP service with one command.

```bash
docker run --detach \
  --name lets-nginx \
  --link backend:backend \
  --env EMAIL=me@email.com \
  --env DOMAIN=mydomain.horse \
  --env UPSTREAM=backend:8080 \
  --publish 80:80 \
  --publish 443:443 \
  smashwilson/lets-nginx
```

Issues certificates from [letsencrypt](https://letsencrypt.org/), installs them in [nginx](https://www.nginx.com/), and schedules a cron job to reissue them monthly.

:zap: To run unattented, this container accepts the letsencrypt terms of service on your behalf. Make sure that the [subscriber agreement](https://letsencrypt.org/repository/) is acceptable to you before using this container. :zap:

## Prerequisites

Before you begin, you'll need:

 1. A [place to run Docker containers](https://getcarina.com/) with a public IP.
 2. A domain name with an *A record* pointing to your cluster.

## Usage

Launch your backend container and note its name, then launch `smashwilson/tls-nginx` with the following parameters:

 * `--link backend:backend` to link your backend service's container to this one. *(This may be unnecessary depending on Docker's [networking configuration](https://docs.docker.com/engine/userguide/networking/dockernetworks/).)*
 * `-e EMAIL=` your email address, used to register with letsencrypt.
 * `-e DOMAIN=` the domain name.
 * `-e UPSTREAM=` the name of your backend container and the port on which the service is listening.
 * `-p 80:80` and `-p 443:443` so that the letsencrypt client and nginx can bind to those ports on your public interface.
