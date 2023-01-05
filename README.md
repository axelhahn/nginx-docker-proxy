# Nginx proxy for multiple docker containers

## Description

I wanted to map the exposed ports of webapps in docker containers to readable names.

The shellscript adds 

* a hostname to /etc/conf and 
* creates a vhost config for nginx with a a proxy rule.

## Installation

(1) extract source or git clone
(2) Install Nginx.

## Configuration

### Setup your docker containers and ports

Copy `docker-hosts.cfg.dist` to `docker-hosts.cfg`.

Add your docker apps of all containers in the docker-hosts.cfg.
For multiple host to port mappings write each into a new line.

Syntax:

`HOSTNAME:PORT`

Example

```txt
exampleweb.docker:8000
examplecms.docker:8002
myapp.docker:8003
```

### Setup Nginx

as root

`cd /etc/nginx`

In the `nginx.conf` add an include rule inside the http section to load /etc/nginx/vhost.d/*.conf.

```txt
...
http {
    ...
    include /etc/nginx/vhost.d/*.conf;
    ...
}
```

## Usage

start `sudo ./generate-proxy.sh`.
Use sudo or start it as as root to add missing hosts into /etc/hosts and to update nginx config and restart its service.

This command

* Loops over all defined hostnames with its port
  * create an entry in /etc/hosts with "127.0.0.1 <HOST>"
  * create a self signed SSL certificate for <HOST>
  * create a nginx vhost config file for ports 80, 443 with proxy rule to http to docker port.
* Update/ restart nginx
  * link nginx config dir as /etc/nfinx/vhosts.d/
  * checks nginx config with `nginx -t`
  * restarts nginx service
* Shows configured https urls
