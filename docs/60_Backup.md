
## What to backup?

In your backup software you need as minimum these real data :

1) `/etc/hosts` (but I guess you already added `/etc/`)
2) `/opt/docker-proxy/nginx_config/` for the generated Nginx vhosts and certificates
3) optional: `/opt/docker-proxy/docker-hosts.cfg`

For 2+3) The project are just a few text files and shell scripts. If you add `/opt/docker-proxy/` you backup a few kilobytes of data.
