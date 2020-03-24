#!/bin/bash

# Verify user is root
if [ "$EUID" -ne 0 ]
	then echo "Error: Please run as root"
	exit 2
fi

# Detect OS Version
if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID

elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS=Debian
    VER=$(cat /etc/debian_version)
elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    ...
elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    ...
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi

# Generate dependency install commands by OS
SUPPORTED=0

case "$OS" in
"Arch Linux" | "Manjaro Linux")
    COUCHINSTALL="pacman -S couchdb"
    CURLINSTALL="pacman  -S curl"
    IPS=`ip address show | grep 'inet ' | awk -F '/' '{print $1}' | awk '{print "    " $2}'`
    SUPPORTED=1
    ;;
"Ubuntu" | "Manjaro Linux")
    COUCHINSTALL="apt-get install couchdb"
    CURLNSTALL="apt-get install curl"
    LISTIPS=`ifconfig | grep 'inet addr' | awk  '{print $2}' | awk -F ':' '{print "    " $2}'`
    SUPPORTED=1
    ;;
"FreeBSD")
    COUCHINSTALL="pkg install couchdb2"
    CURLINSTALL="pkg install curl"
    LISTIPS=`ifconfig | grep 'inet ' | awk '{print "    " $2}'`
    SUPPORTED=1
    ;;
*)
    if [ "$SUPPORTED" != 1 ]; then
        echo "Error: $OS Not supported. Please install dependencies manually"
        exit 3
    fi
    ;;
esac

install_package() {
    printf "\n$1? [Y/N]"
    read DOINSTALL
    DOINSTALL=`echo $DOINSTALL | awk '{print toupper($0)}'`

    if [ "$DOINSTALL" == "Y" ]; then
        `$2`
    fi
}

read_with_default() {
    read RESPONSE

    if [ "$RESPONSE" == "" ]; then
        echo $1
    else
        echo $RESPONSE
    fi
}

printf "\n$OS detected.\n\n"

install_package "Install CouchDB" "$COUCHINSTALL"
install_package "Install cURL" "$CURLINSTALL"

printf "\nThe following IP Addresses have been detected:\n$IPS\n"

echo -n "CouchDB URL [127.0.0.1]:"
COUCHIP=`read_with_default "127.0.0.1"`

CONFIG=$(cat <<_EOF_
{
  "node": {
    "memoryRecordLimit": 40
  },
  "network": {
    "consensusAlgorithm": "raft",
    "role": 2,
    "maxPeers": 10,
    "discoveryURL": [
      "http://127.0.0.1"
    ],
    "comments": {
      "consensusAlgorithm": "Currently only 'raft' is available (string)",
      "role": "Default role of node on network. '0':dynamic, '1':follow, '2':lead (integer)",
      "maxPeers": "Maximum number of concurrent peer connections (integer)",
      "discoverURL": "Array of URLs to use when discovering peers"
    }
  },
  "logging": {
    "enabled": true,
    "level": 4,
    "console": true,
    "file": false,
    "fileLocation": "/var/log/proliferate",
    "comments": {
      "enabled": "Enables/disables all logging. Available values (boolean)",
      "level": "Log level, higher numbers produce more logs. (integer) Values: '0': Fatal, '1': Error, '2': Warning, '3': Notice, '4': Verbose, '5': Noisy",
      "console": "Emit logs to console (boolean)'",
      "file": "Log output file location (string)"
    }
  },
  "couchDB": {
    "enabled": true,
    "host": "$COUCHIP",
    "port": "5984",
    "protocol": "http",
    "database": "proliferate",
    "comments": {
      "enabled": "Enables/disables CouchDB for block storage",
      "host": "CouchDB host domain or IP",
      "port": "CouchDB http port",
      "protocol": "HTTP protocol 'http' or 'https' (string)"
    }
  }
}
_EOF_
)


printf "\n$CONFIG\n"

