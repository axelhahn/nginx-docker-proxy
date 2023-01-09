# Nginx proxy for multiple docker containers

## Description

On my development computer I run multiple docker containers for different apps. I wanted to map the exposed ports of webapps in docker containers to readable hostnames.

### Default way

If you run docker containers directly then you open `http://localhost:PORT` for each app and need to remember the configured portnumbers.

![](./docs/images/docker-proxy-overview-Page-1.drawio.png)

### If using a proxy

The proxy translates `http(s)://[APPNAME]/` to `http://localhost:portnumber/` for a simpler access to a docker aoo. For each request it makes a backend request to the current container ports.

![](./docs/images/docker-proxy-overview-Page-2.drawio.png)

Remark: This is a proxy for your local access with a webbrowser only. It does not effect any docker internal access from one app to another.

The generator shellscript

* adds your wanted hostnames to /etc/conf and
* creates a self signed ssl certificate for each hostname
* creates a vhost config for nginx with a proxy rule to its docker container port

## Requirements

* Nginx. I suggest to use the package manager of your os, eg.
  * `apt-get install nginx` - Debian
  * `pamac install nginx` - Arch/ Manjaro
  * `yum install nginx` - CentOS
* OpenSSL. It is used to create a self signed SSL certificate to use https.

## Installation

* extract source or git clone. Go into your directory where to create a subdir for the proxy generator script.

```txt
cd ~/scripts/
```
get the software
```txt
git clone https://github.com/axelhahn/nginx-docker-proxy.git
```
which creates a subdir named "nginx-docker-proxy" ... or add a directory name behind:
```txt
git clone https://github.com/axelhahn/nginx-docker-proxy.git [your_custom_dir]
```

## Configuration

### Prepare Nginx config

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

### Setup your docker containers and ports

Copy `docker-hosts.cfg.dist` to `docker-hosts.cfg`.

Add your docker apps of all containers in the docker-hosts.cfg.
For multiple host to port mappings write each into a new line.

Syntax:

`HOSTNAME:PORT`

Example

```txt
exampleweb.docker:8000
examplecms.docker:8001
myapp.docker:8002
```

## Usage

Start `sudo ./generate-proxy.sh`. There is no parameter requirerd - it reads the config file.
Use sudo or start it as as root to add missing hosts into /etc/hosts and to update nginx config and restart its service.

This command

* Loops over all defined hostnames with its port
  * create an entry in /etc/hosts with "127.0.0.1 [HOSTNAME]"
  * create a self signed SSL certificate for [HOSTNAME]
  * create a nginx vhost config file for ports 80, 443 with proxy rule to http to docker port.
* Update/ restart nginx
  * link nginx config dir as /etc/nfinx/vhosts.d/
  * checks nginx config with `nginx -t`
  * restarts nginx service
* Shows configured https urls
