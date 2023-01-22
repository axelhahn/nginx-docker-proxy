#!/bin/bash
# ======================================================================
#
# AXELS PROXY GENERATOR FOR DOCKER CONTAINERS
#
# ----------------------------------------------------------------------
# 2023-01-05 v0.1 wwww.axel-hahn.de initial version
# 2023-01-09 v0.2 wwww.axel-hahn.de show diff of vhost config
# 2023-01-14 v0.3 wwww.axel-hahn.de handle running and starting docker containers
# 2023-01-21 v0.4 wwww.axel-hahn.de replace rev by awk
# 2023-01-22 v0.5 wwww.axel-hahn.de update output of --show param
# ======================================================================
# ------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------
_version=0.5
comment="# ADDED BY DOCKERPROXY "
hostsfile=/etc/hosts
nginxconfdir=/etc/nginx/vhost.d
nginxhosts=nginx_config
cd "$( dirname $0 )" || exit 1
selfdir=$( pwd )
self=$( basename $0 )
configfile="$selfdir/docker-hosts.cfg"

FLAG_DEBUG=0
FLAG_RESTART=1
FLAG_LOOP=0
REDIRECT=/dev/null
USAGE="
This script generates nginx config files for http(s) connections to the docker
container with human readable hostnames instead of localhost:PORTNUMBER.

SYNTAX
    $self [OPTIONS]

OPTIONS
    -f|--hostsfile FILE  set a hosts file; default: $hostsfile
    -h|--help            show this help and exit
    -l|--loop            enable loop to detect starting docker containers
    -n|--noloop          disable loop to detect starting docker containers
    -s|--show            show configuration and generated entries and exit
    -v|--verbose         show more output
"
# ------------------------------------------------------------
# FUNCTIONS
# ------------------------------------------------------------
function _h1(){
    echo
    echo -e "\e[33m############### $*\e[0m"
    echo
}
function _h2(){
    echo
    echo -e "\e[34m========== $*\e[0m"
}
function _h3(){
    echo -e "\e[35m>>>>> $*\e[0m"
}
function _wd(){
    test $FLAG_DEBUG -ne 0 && echo -e "\e[1;30m> $*\e[0m"
}
# helper
# get real config entries from docker-hosts.cfg
function _getStaticConfig(){
    grep "^[a-z].*" "$configfile" 2>/dev/null | sort
}
# helper
# get all hostnames from config
function _getStaticHosts(){
    _getStaticConfig | cut -f 1 -d ':'
}
# main function:
# loop over all config entries and process hosts
function _checkContainers(){
    for myhost in $( _getStaticHosts )
    do
        targetport=$( _getStaticConfig | grep "^$myhost:" | cut -f 2 -d ":" )
        _h3 "$myhost on port $targetport"
        _updateEtcHosts "$myhost"
        _createSslCert "$myhost"
        _updateNginxConf "$myhost" "$targetport"
        if ( sudo netstat -tulpen | grep ":$targetport" >/dev/null ); then
            _wd "OK, container is running"
        else
            _wd "INFO: Container does not run"
        fi
        echo
    done
}
# handle docker container
# param  string  name of docker container
function _handleDockercontainer(){
    local myhost=$1
    portmapping=$( $DOCKERCMD inspect --format '{{ .HostConfig.PortBindings }}' $myhost )
    # result: "map[80/tcp:[{ 8000}]]"
    portinside=$( echo "$portmapping" | cut -f 2 -d '[' | cut -f 1 -d '/' )
    portexposed=$( echo "$portmapping" | cut -f 2 -d '{' | cut -f 1 -d '}' | tr -d " " )
    _h3 "$myhost ... $portmapping"
    # echo "$myhost - id $dockerid - $portmapping ... $portinside to $portexposed"
    if $DOCKERCMD exec $myhost curl -I -q http://localhost:$portinside 2>/dev/null | grep -i "http/" > $REDIRECT; then
        _wd "--> container uses an http service on port :$portinside"
        echo "OK, can be enabled for Nginx proxy to local port $portexposed"
        _updateEtcHosts "$myhost"
        _createSslCert "$myhost"
        _updateNginxConf "$myhost" "$portexposed"
    else
        echo "SKIP: :$portinside is no http"
    fi
}

# ensure that hostname exists in /etc/hosts
# param string hostname (from config file)
function _updateEtcHosts(){
    local myhost=$1
    if ! grep " $myhost" $hostsfile >/dev/null; then
        _wd "Adding [$myhost] to $hostsfile ..."
        if ! echo 127.0.0.1 $myhost $comment $( date ) | sudo tee -a $hostsfile
        then
            echo "ERROR: unable to write $myhost into $hostsfile"
            exit 1
        else
            _wd "$myhost was added into $hostsfile"
            FLAG_RESTART=1
        fi
    else
        _wd "SKIP: $myhost was added into $hostsfile already"
    fi
}
# ensure that ssl key and cert exist
# param string hostname (from config file)
function _createSslCert(){
    local myhost=$1
    local keyfile=$nginxhosts/$myhost.key
    local certfile=$nginxhosts/$myhost.crt
    if test -f ${certfile}; then
        _wd "SKIP: cert already exists: ${certfile}"
    else
        openssl req -nodes -x509 -newkey rsa:4096 \
            -keyout ${keyfile} \
            -out ${certfile} \
            -days 365 \
            -subj "/CN=${myhost}" \
            -addext "subjectAltName=DNS:${myhost},IP:127.0.0.1" \
        || exit 1
        FLAG_RESTART=1
    fi
}
# ensure that nginx config for the host exist
# it is ssl enabled and contains a proxy rule to the docker port
# param string hostname (from config file)
# param integer port (from config file)
function _updateNginxConf(){
    local myhost=$1
    local targetport=$2
    local conffile=$nginxhosts/vhost_$myhost.conf
    local keyfile=$nginxhosts/$myhost.key
    local certfile=$nginxhosts/$myhost.crt
    echo "
    server{
        listen 80;
        listen 443 ssl;
        server_name $myhost;
        ssl_certificate         ${nginxconfdir}/$( basename ${certfile} );
        ssl_trusted_certificate ${nginxconfdir}/$( basename ${certfile} );
        ssl_certificate_key     ${nginxconfdir}/$( basename ${keyfile}  );
        location /
        {
            proxy_pass http://127.0.0.1:$targetport;
        }
    }
    ">"$conffile.tmp"
    local bOverwrite=1
    if test -f "${conffile}" ; then
        if diff --color "$conffile" "$conffile.tmp"; then
            _wd "SKIP: config $conffile has no change."
            rm -f "$conffile.tmp"
            local bOverwrite=0
        fi
    fi
    if [ $bOverwrite -eq 1 ]; then
        _wd "OK, Writing new config $conffile ..."
        if mv -f "$conffile.tmp" "$conffile"; then
            echo "OK, file $conffile was written"
            FLAG_RESTART=1
        else
            echo "ERROR: unable to write file."
            exit 2
        fi
    fi
}
# check nginx global config and restart service
function _updateNginx(){
    _h3 "Check link ${nginxconfdir} ..."
    cd "$( dirname ${nginxconfdir} )" || exit 1
    if ! sudo grep "include.*$nginxconfdir" nginx.conf >/dev/null; then
        echo "ERROR: you need to modify the nginx.conf. In http section add a include:"
        echo "include $nginxconfdir/*.conf;"
        exit 1
    fi
    _wd "OK, include rule was added in nginx.conf."
    _wd "setting link to vhost config: ${selfdir}/${nginxhosts} -> ${nginxconfdir}"
    sudo rm -f "${nginxconfdir}"
    sudo ln -s "${selfdir}/${nginxhosts}" "${nginxconfdir}"
    ls -l "${selfdir}/${nginxhosts}" >$REDIRECT || exit 2
    cd - >/dev/null
    _restartNginx
}
# restart nginx service
function _restartNginx(){
    _h3 "Restart Nginx"
    if [ $FLAG_RESTART -eq 1 ]; then
        if sudo nginx -t 2>$REDIRECT; then
            echo -n "Config OK... Restarting service... "
            if sudo systemctl restart nginx ; then
                echo OK
                FLAG_RESTART=0
            else
                echo "FAILED :-/"
                sudo systemctl status nginx
                exit 1
            fi
           
        else
            exit 1
        fi
    else
        echo "SKIP: no change yet"
    fi
    }
# helper: check if a required binary is in $PATH (= installed)
function _checkRequiredBin(){
    if ! which $1 >/dev/null; then
        echo "ERROR: required binary $1 is not available"
        exit 1
    else
        _wd "OK, $1 was found"
    fi
}
function _UNUSED_showUrls(){
    for myhost in $( _getStaticHosts )
    do
        echo " https://${myhost}"
        curl -ki "https://${myhost}"
    done
}

# show created configuration
function _showProxiedHosts(){
    local srv=

    _h1 "S H O W"
    _h2 "Static mappings in $configfile"
    _getStaticConfig | grep "." || echo "None"

    _h2 "Generated entries in $hostsfile"
    grep "$comment" "$hostsfile" || echo "None"

    _h2 "Generated Nginx proxies"
    echo "Loop over found configs and detect running docker instance."
    ls -1 $nginxconfdir/vhost* | while read -r nginxVhost
    do
        srv=$( grep -i "server_name" $nginxVhost | awk '{ print $2 }' | tr -d ";" )
        _h3 $srv
        (
            echo -n "config:   "
            ls -l $nginxVhost
            echo -n "ssl cert: "; ls -l $nginxconfdir/${srv}*.crt
            echo -n "ssl key:  "; ls -l $nginxconfdir/${srv}*.key
            echo -n "hosts:    "
            if grep "$srv $comment" "$hostsfile" >/dev/null; then
                echo -n "OK: $hostsfile:"
                grep -n "$srv $comment" "$hostsfile"
            else
                echo "MISS: $srv does not exist in $hostsfile"
            fi
            echo -n "proxy:    "
            if ! curl -kI "https://${srv}" 2>/dev/null; then
                echo "INFO: https://${srv} is not running"
            else
                echo "OK: https://${srv} is UP."
            fi

        ) | sed "s#^#    #g"
        echo
    done

}

# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------
echo -en "\e[36m"
cat << HEADERTEXT
______________________________________________________________________________


AXELS PROXY GENERATOR FOR DOCKER CONTAINERS
                                                                          ____
_________________________________________________________________________/ $_version


HEADERTEXT
echo -en "\e[0m"

if [ $( id -u ) -eq 0 ]; then
    echo "ABORT: Do not start $self it as root!"
    echo "Run it with a user with sudo permissions."
    exit 1
fi

# parse params
while [[ "$#" -gt 0 ]]; do case $1 in
    # -a|--address) IP_ADDRESS="$2"; shift;shift;;
    # -v|--verbose) VERBOSE=1;shift;;
    # -q|--quiet) QUIET="1";shift;;
    -f|--hostsfile) hostsfile="$2";shift;shift;;
    -h|--help)      _h1 "H E L P"; echo "$USAGE"; exit 0;;
    -l|--loop)      FLAG_LOOP=1;shift;;
    -n|--noloop)    FLAG_LOOP=0;shift;;
    -s|--show)      _showProxiedHosts;exit 0;;
    -v|--verbose)   FLAG_DEBUG=1;REDIRECT=/dev/tty;shift;;
    *) echo "ERROR: Unknown parameter: $1"; echo "${USAGE}"; exit 1;
esac; done

_h1 "I N I T"

_h2 "check requirements"
_checkRequiredBin openssl
_checkRequiredBin docker
_checkRequiredBin nginx
_checkRequiredBin sudo
_checkRequiredBin systemctl

sudo docker ps >/dev/null 2>&1 && DOCKERCMD="sudo docker" && _wd "INFO: Docker runs as root."
docker ps      >/dev/null 2>&1 && DOCKERCMD="docker"      && _wd "INFO: Rootless Docker detected. Good choice! :-)"
echo Passed.

_h2 "Verify nginx config"
_updateNginx

_h2 "Add docker containers in config $configfile"
_checkContainers
echo Passed.

_h2 "Check running docker containers ..."
for appname in $( $DOCKERCMD ps | awk '{ print $NF }' )
do
    _handleDockercontainer "$appname"
done
echo Passed.

_h2 "Check service"
_restartNginx
echo
if [ $FLAG_LOOP -eq 1 ]; then
    _h1 "L O O P"
    _h2 "Listening to docker events ..."
    echo "INFO: If a new docker container comes up it will be added on the fly."
    echo "And you can abort this loop any time and start $self again."
    echo
    echo -n "Waiting for a starting container ..."
    $DOCKERCMD events --filter 'event=start' | while read -r event
    do
        echo
        sleep 1
        eventdata=$( echo "$event" | tr "(" "\n" | tr ")" "\n" | tr " " "\n" )
        appname=$( echo "$eventdata" | grep "^name=" | cut -f 2 -d '=')
        _handleDockercontainer "$appname"
        _restartNginx
        echo
        echo -n "Waiting ..."
    done;
else
    _h2 "DONE"
    _wd "INFO: looping is deactivated (you can use param -l)."
    echo
fi

# ------------------------------------------------------------