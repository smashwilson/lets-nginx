# Let's Nginx

Put browser-valid TLS termination in front of any HTTP service with one command.

```bash
docker run -d --name tls-nginx \
  -e EMAIL=me@email.com \
  -e DOMAIN=mydomain.horse \
  -e UPSTREAM=backend:4567 \
  -p 80:80 -p 443:443 \
  smashwilson/tls-nginx
```

## Prerequisites

Before you begin, you'll need:

 1. A [place to run Docker containers](https://getcarina.com/) with a public IP.
 2. A domain name with an *A record* pointing to your cluster.

## Usage

Launch your backend container and note its name, then launch `smashwilson/tls-nginx` with the following parameters:

 * `-e EMAIL=` your email address, used to register with letsencrypt.
 * `-e DOMAIN=` the domain name.
 * `-e UPSTREAM=` the name of your backend container and the port on which the service is listening.
 * `-p 80:80` and `-p 443:443` so that the letsencrypt client and nginx can bind to those ports on your public interface.
