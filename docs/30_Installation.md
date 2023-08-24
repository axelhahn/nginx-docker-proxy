## Installation

### Get the software

You can extract source or use `git clone`. Go into your directory where to create a subdir for the proxy generator script.
I describe an installation below /opt - it requires root or sudo permissions.

```txt
sudo -i
mkdir /opt
cd /opt
```

Get the software

```txt
git clone https://github.com/axelhahn/nginx-docker-proxy.git
```

which creates a subdir named "nginx-docker-proxy".

### Set owner

Change the owner of /opt/nginx-docker-proxy/ to your local user. My user I login into the desktop is "axel":

```txt
chown -R axel:axel /opt/nginx-docker-proxy/
```

### Prepare Nginx config 

#### Add include

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

#### Add softlink

After telling to load something fron /etc/nginx/vhost.d/ we need to set a link to our custom config:

```txt
cd /etc/nginx
mv vhost.d vhost.d__bak
ln -s /opt/docker-proxy/nginx_config vhost.d
```