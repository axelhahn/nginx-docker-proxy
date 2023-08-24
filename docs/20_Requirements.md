## Requirements

I started this script to handle local docker containers for my private projects.

On the local computer you need to install:

* **Nginx**. I suggest to use the package manager of your os, eg.
  * `apt-get install nginx` - Debian
  * `pamac install nginx` - Arch/ Manjaro
  * `yum install nginx` - CentOS
  <br><br>
* **OpenSSL**. It is used to create a self signed SSL certificate to use https.
  <br><br>
* Your user must have **sudo permissions**.
  <br><br>
* **Docker**. Bring up to live the docker daemon and a docker container with a web application using an http service.