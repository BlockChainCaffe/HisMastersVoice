#!/bin/bash
## HMV installation script

set -u

SRCDIR=$(cd "$(dirname "$0")" && pwd)
INSTALLDIR=/opt/hmv
CRONFILE=/etc/cron.d/hmv
CRON_SCHEDULE="0 3 * * *"

## Functions ################
terminate () {
    echo "install: $1" >&2
    exit 1
}

checkinstall () {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "install: installing $1"
        if command -v apt-get >/dev/null 2>&1; then
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$1" || terminate "failed to install $1"
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y "$1" || terminate "failed to install $1"
        elif command -v yum >/dev/null 2>&1; then
            yum install -y "$1" || terminate "failed to install $1"
        elif command -v apk >/dev/null 2>&1; then
            apk add --no-cache "$1" || terminate "failed to install $1"
        else
            terminate "no known package manager; please install $1 manually"
        fi
    fi
}

## Are we root ??
if [ "$(id -u)" != 0 ]; then
    terminate "script must be run as root"
fi

## Dependency check
checkinstall bash
checkinstall gpg
checkinstall cron
checkinstall wget
checkinstall curl
checkinstall git
checkinstall rsync

## Install HMV in $INSTALLDIR
mkdir -p "$INSTALLDIR" || terminate "cannot create $INSTALLDIR"
if [ "$SRCDIR" != "$INSTALLDIR" ]; then
    cp -f "$SRCDIR/hmv.sh" "$INSTALLDIR/hmv.sh" || terminate "cannot copy hmv.sh to $INSTALLDIR"
fi
chmod 755 "$INSTALLDIR/hmv.sh" || terminate "cannot chmod $INSTALLDIR/hmv.sh"
chown root:root "$INSTALLDIR/hmv.sh" 2>/dev/null || true

## Warn if the sources are still unconfigured
if ! grep -qE '^[[:space:]]*"[a-z]+\|' "$INSTALLDIR/hmv.sh"; then
    echo "install: NOTE: no download sources configured; edit SOURCES in $INSTALLDIR/hmv.sh" >&2
fi

## Schedule HMV via cron (daily, as root)
mkdir -p "$(dirname "$CRONFILE")" || terminate "cannot create $(dirname "$CRONFILE")"
cat > "$CRONFILE" <<EOF
# HMV - His Master's Voice: daily run as root
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
$CRON_SCHEDULE root $INSTALLDIR/hmv.sh >/dev/null 2>&1
EOF
chmod 644 "$CRONFILE" || terminate "cannot chmod $CRONFILE"
chown root:root "$CRONFILE" 2>/dev/null || true

## Restart cron so the new entry is picked up
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart cron 2>/dev/null || systemctl restart crond 2>/dev/null || true
elif command -v service >/dev/null 2>&1; then
    service cron restart 2>/dev/null || service crond restart 2>/dev/null || true
fi

echo "install: HMV installed in $INSTALLDIR and scheduled via $CRONFILE ($CRON_SCHEDULE)"
