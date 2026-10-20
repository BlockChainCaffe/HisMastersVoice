#!/bin/bash
# HMV example script: emergency remote shell.
#
# USE CASE
#   You locked yourself out of a remote server (e.g. a firewall rule slammed
#   the door shut). You cannot SSH in anymore. HMV still runs via cron, so you
#   drop this signed script as a source, and it opens a plain shell that you
#   can reach with nc from anywhere.
#
# HOW IT WORKS
#   Starts an interactive bash bound to a TCP port on all interfaces (0.0.0.0)
#   using one of the available tools, in order of preference:
#     - socat
#     - ncat / nc with -e support (OpenBSD netcat, ncat)
#     - nc from netcat-traditional (Debian's nc.traditional)
#
# RUN AT YOUR OWN RISK
#   This exposes an UNAUTHENTICATED root shell to anyone who can reach the port.
#   Anyone who finds it owns the box. Prefer SSH if at all possible; use this
#   only for recovery, and close the port / kill the process as soon as you are
#   done. Optionally restrict access with a firewall rule to your own IP.

PORT=4444
SHELL_BIN=/bin/bash

# Optional: only accept connections from this IP. Leave empty to accept anyone.
ALLOW_FROM=""
# ALLOW_FROM="203.0.113.7"

open_with_socat () {
    echo "hmv-example: listening on 0.0.0.0:$PORT with socat" >&2
    if [ -n "$ALLOW_FROM" ]; then
        exec socat \
            "TCP-LISTEN:$PORT,reuseaddr,fork,range=$ALLOW_FROM" \
            "EXEC:$SHELL_BIN -li"
    fi
    exec socat \
        "TCP-LISTEN:$PORT,reuseaddr,fork" \
        "EXEC:$SHELL_BIN -li"
}

if command -v socat >/dev/null 2>&1; then
    open_with_socat
elif command -v ncat >/dev/null 2>&1; then
    echo "hmv-example: listening on 0.0.0.0:$PORT with ncat" >&2
    if [ -n "$ALLOW_FROM" ]; then
        exec ncat -k -l "$PORT" --allow "$ALLOW_FROM" -e "$SHELL_BIN"
    fi
    exec ncat -k -l "$PORT" -e "$SHELL_BIN"
elif command -v nc >/dev/null 2>&1 && nc -h 2>&1 | grep -q -- '-e'; then
    echo "hmv-example: listening on 0.0.0.0:$PORT with nc -e" >&2
    [ -n "$ALLOW_FROM" ] && echo "hmv-example: note: this nc cannot filter by IP, exposing to any source" >&2
    exec nc -l -p "$PORT" -e "$SHELL_BIN"
else
    echo "hmv-example: no socat/ncat/nc with -e; installing socat" >&2
    if command -v apt-get >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y socat || exit 1
        open_with_socat
    fi
    echo "hmv-example: cannot open a shell, giving up" >&2
    exit 1
fi
