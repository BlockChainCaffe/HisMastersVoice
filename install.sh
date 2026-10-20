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
    if command -v "$1" >/dev/null 2>&1; then
        return 0
    fi
    echo "install: installing $1"
    if command -v apt-get >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$1" || warn "failed to install $1"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y "$1" || warn "failed to install $1"
    elif command -v yum >/dev/null 2>&1; then
        yum install -y "$1" || warn "failed to install $1"
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache "$1" || warn "failed to install $1"
    else
        warn "no known package manager; please install $1 manually"
    fi
}

warn () {
    echo "install: $1" >&2
}

## cron is a service, not always a binary: treat it as present if the command
## exists or a known service unit/script does
cron_present () {
    command -v cron >/dev/null 2>&1 && return 0
    command -v crond >/dev/null 2>&1 && return 0
    command -v cronie >/dev/null 2>&1 && return 0
    if command -v systemctl >/dev/null 2>&1; then
        systemctl list-unit-files 2>/dev/null | grep -qE '^(cron|crond)\.service' && return 0
    fi
    if command -v service >/dev/null 2>&1; then
        service --status-all 2>&1 | grep -qE '\b(cron|crond)\b' && return 0
    fi
    return 1
}

## is cron currently running as a service?
cron_running () {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl is-active --quiet cron 2>/dev/null && return 0
        systemctl is-active --quiet crond 2>/dev/null && return 0
    fi
    if command -v service >/dev/null 2>&1; then
        service cron status >/dev/null 2>&1 && return 0
        service crond status >/dev/null 2>&1 && return 0
    fi
    return 1
}

## Are we root ??
if [ "$(id -u)" != 0 ]; then
    terminate "script must be run as root"
fi

## Dependency check (best effort: a failure to install only warns, never halts)
checkinstall bash
checkinstall gpg
checkinstall wget
checkinstall curl
checkinstall git
checkinstall file
checkinstall rsync

## cron: install it only if not already provided by the system
if ! cron_present; then
    checkinstall cron
fi

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

## Restart cron so the new entry is picked up (only if it is actually running)
if cron_running; then
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart cron 2>/dev/null || systemctl restart crond 2>/dev/null || true
    elif command -v service >/dev/null 2>&1; then
        service cron restart 2>/dev/null || service crond restart 2>/dev/null || true
    fi
else
    echo "install: NOTE: cron does not appear to be running; start it for HMV to run" >&2
fi

echo "install: HMV installed in $INSTALLDIR and scheduled via $CRONFILE ($CRON_SCHEDULE)"
