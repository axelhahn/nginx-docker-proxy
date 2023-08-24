## Configuration

### Setup static docker containers and ports

**Remark:** Adding static definitions for containers and ports is optional.

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