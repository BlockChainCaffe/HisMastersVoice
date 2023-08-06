#!/bin/bash
## HMV installation script 

## Functions ################
terminate () {
    print $1
    exit
}

checkinstall () {
    which $1
    if [[ $? != 0 ]]; then
        apt-get install -y $1
    fi
}

## Are we root ??
ID=$(id -u)
if [[ x$ID != x0 ]]; then
    terminate "script must be run as root"
fi

## Dependecy check
checkinstall gpg
checkinstall bash