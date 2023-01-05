#!/bin/bash
# ======================================================================
#
# AXELS PROXY GENERATOR FOR DOCKER CONTAINERS
#
# ----------------------------------------------------------------------
# 2023-01-05  v0.1  wwww.axel-hahn.de   initial version
# ======================================================================


# ------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------

_version=0.1
comment="# ADDED BY DOCKERPROXY "
hostsfile=/etc/hosts

nginxconfdir=/etc/nginx/vhost.d
nginxhosts=nginx_config

cd "$( dirname $0 )" || exit 1
selfdir=$( pwd )

# ------------------------------------------------------------
# FUNCTIONS
# ------------------------------------------------------------

# helper
# get real config entries from docker-hosts.cfg 
function _getConfigdata(){
    grep "^[a-z].*" "$selfdir/docker-hosts.cfg" | sort
}

# helper
# get all hostnames from config
function _getHosts(){
    _getConfigdata | cut -f 1 -d ':'
}

# main function:
# loop over all config entries and process hosts
function _checkContainers(){
    for myhost in $( _getHosts )
    do
        targetport=$( _getConfigdata | grep "^$myhost:" | cut -f 2 -d ":" )

        echo ">>>>> $myhost on port $targetport"

        _updateEtcHosts  "$myhost"
        _createSslCert   "$myhost"
        _updateNginxConf "$myhost" "$targetport"

        if ( netstat -tulpen | grep ":$targetport" >/dev/null ); then
            echo "OK, container is running"
        else
            echo "Container does not run"
        fi
        echo
    done
}

# ensure that hostname exists in /etc/hosts
# param  string  hostname (from config file)
function _updateEtcHosts(){
    local myhost=$1
    if ! grep " $myhost" $hostsfile >/dev/null; then
        echo Adding $myhost to $hostsfile

        if ! echo >> $hostsfile; then
            echo HINT: call $0 with sudo to write $hostsfile
        else
            echo $comment >> $hostsfile
            echo 127.0.0.1 $myhost >> $hostsfile
        fi
    else
        echo -n "OK, exists in $hostsfile: "
        grep -n " $myhost" $hostsfile
    fi
}

# ensure that ssl key and cert exist
# param  string  hostname (from config file)
function _createSslCert(){
    local myhost=$1
    local keyfile=$nginxhosts/$myhost.key
    local certfile=$nginxhosts/$myhost.crt

    if test -f ${certfile}; then
        echo OK, cert already exists: ${certfile}
    else
		openssl req -nodes -x509 -newkey rsa:4096 \
			-keyout ${keyfile}         \
			-out ${certfile}           \
			-days 365            \
			-subj "/CN=${myhost}" \
			-addext "subjectAltName=DNS:${myhost},IP:127.0.0.1" \
			|| exit 1

    fi
}

# ensure that nginx config for the host exist
# it is ssl enabled and contains a proxy rule to the docker port
# param  string   hostname (from config file)
# param  integer  port (from config file)
function _updateNginxConf(){
    local targetport=$2
    local conffile=$nginxhosts/vhost_$myhost.conf

    local keyfile=$nginxhosts/$myhost.key
    local certfile=$nginxhosts/$myhost.crt

    if test -f "${conffile}" ; then
        if ( grep "server_name $myhost" "${conffile}" && grep "http://127.0.0.1:$targetport;" "${conffile}" ) >/dev/null; then
            echo "OK, nginx config already exists: ${conffile}"
        else
            echo "Exists: $conffile ... but server or port do not match."
            cat "${conffile}"
        fi
    else
        echo "Creating ${conffile}"
        echo "
server{
        listen 80;
        listen 443 ssl;
            
        server_name $myhost;

        ssl_certificate          ${nginxconfdir}/$( basename ${certfile} );
        ssl_trusted_certificate  ${nginxconfdir}/$( basename ${certfile} );
        ssl_certificate_key      ${nginxconfdir}/$( basename ${keyfile}  );

        location /
        {
                proxy_pass http://127.0.0.1:$targetport;
        }
}
" >$conffile
    fi
}

# update nginx config and restart service
function _updateNginx(){

    cd "$( dirname ${nginxconfdir} )" || exit 1

    if ! grep "include.*$nginxconfdir" nginx.conf >/dev/null; then
        echo "ERROR: you need to modify the nginx.conf. In http section add a include:"
        echo "include $nginxconfdir/*.conf;"
        exit 1
    fi
    echo "OK, include rule was added in nginx.conf."

    echo "setting link to vhost config: ${selfdir}/${nginxhosts} -> ${nginxconfdir}"
    rm -f "${nginxconfdir}"
    ln -s "${selfdir}/${nginxhosts}" "${nginxconfdir}"
    ls -l "${selfdir}/${nginxhosts}" || exit 2
    echo

    echo "test config:"
    nginx -t && echo "Restarting Nginx..." && systemctl restart nginx && echo OK
    cd - >/dev/null
    echo
}

function _checkRequiredBin(){
    if ! which $1 >/dev/null; then
        echo "ERROR: required binary $1 is not available"
        exit 1
    else
        echo "OK, $1 was found"
    fi
}

function _showUrls(){
    for myhost in $( _getHosts )
    do
        echo "    https://${myhost}"
    done
}

# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------

cat << HEADERTEXT
________________________________________________________________________


AXELS PROXY GENERATOR FOR DOCKER CONTAINERS
                                                                    ____
___________________________________________________________________/ $_version


HEADERTEXT

echo "========== check requirements"
echo
_checkRequiredBin openssl
_checkRequiredBin nginx
echo

echo "========== process docker hosts"
echo
_checkContainers

echo "========== Update and restart nginx"
echo
_updateNginx

echo "========== DOME: These urls are configured now for local access"
echo
_showUrls
echo

# ------------------------------------------------------------
