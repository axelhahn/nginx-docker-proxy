
## Usage

All commands have to be executed with your local user (that has sudo permissions).

### Show help

Start `./generate-proxy.sh -h` to see the supported parameters.

```txt
SYNTAX
    generate-proxy.sh [OPTIONS]

OPTIONS
    -c|--cleanup         check configuration to clenaup old entries and exit
    -f|--hostsfile FILE  set a hosts file; default: /etc/hosts
    -h|--help            show this help and exit
    -l|--loop            enable loop to detect starting docker containers
    -n|--noloop          disable loop to detect starting docker containers
    -s|--show            show configuration and generated entries and exit
    -v|--verbose         show more output
```

### Create a vhost

To generate an nginx vhost with a self signed SSL for a docker container:

* First start your docker container with an http service inside. 
* Then start `./generate-proxy.sh` without parameters.

This command

* Loops over all defined hostnames with its port in `docker-hosts.cfg`
  * create an entry in /etc/hosts with "127.0.0.1 [HOSTNAME]"
  * create a self signed SSL certificate for [HOSTNAME]
  * create a nginx vhost config file for ports 80, 443 with proxy rule to http to docker port.
* Loops over all running docker containers and check if they offer an http service
  * create an entry in /etc/hosts with "127.0.0.1 [HOSTNAME]"
  * create a self signed SSL certificate for [HOSTNAME]
  * create a nginx vhost config file for ports 80, 443 with proxy rule to http to docker port.
* Update/ restart nginx
  * link nginx config dir as /etc/nfinx/vhosts.d/
  * checks nginx config with `nginx -t`
  * restarts nginx service

If a new proxy was generated you can access it with ``https://[appname]``.

### Listen mode

You also can let the script wait for starting containers: add the parameter `-l`:
Start `./generate-proxy.sh -l` or `./generate-proxy.sh --loop`. 

This does the same like described in the section above. Add the end it waits for docker events and will add new (non existing) docker hosts into hosts file and create a new Nginx config file.

### Show config

Start `./generate-proxy.sh -s` or `./generate-proxy.sh --show`.

It shows you all generated entries for docker container proxies in different sections:

* generated hosts in /etc/hosts 
* Nginx vhost configs and ssl certificate files. You get an information if this host is currently running or not.
* ports of docker containers. You get a warning if you have defined docker containers that expose their http service to the same port.

### Cleanup

Start `./generate-proxy.sh -c` or `./generate-proxy.sh --cleanup`.

This remove all configuration entries of currently not running docker containers:

* generated entries in /etc/host (excluding those that are defined in docker-hosts.cfg)
* Nginx vhost configs and ssl certificate files.

