#!/bin/bash
# HMV example script: disable the firewall.
#
# USE CASE
#   You locked yourself out with a bad firewall rule (the reason HMV exists).
#   HMV still runs via cron, so you sign and publish this script as a source;
#   the server runs it and the firewall stops blocking you.
#
# HOW IT WORKS
#   Disables whatever firewall is found: ufw, firewalld, or raw iptables/nft.
#   It does NOT make the change persistent beyond the running config: on reboot
#   the original firewall may come back, which is a safety net. Rules that were
#   saved to disk are left untouched.
#
# RUN AT YOUR OWN RISK
#   This removes your packet filtering, briefly exposing the server. Re-enable a
#   proper firewall once you are back in.

echo "hmv-example: disabling firewall" >&2

if command -v ufw >/dev/null 2>&1; then
    echo "hmv-example: ufw disable" >&2
    ufw --force disable
fi

if command -v firewall-cmd >/dev/null 2>&1; then
    echo "hmv-example: firewalld stop" >&2
    systemctl stop firewalld 2>/dev/null || service firewalld stop 2>/dev/null || true
fi

if command -v iptables >/dev/null 2>&1; then
    echo "hmv-example: flushing iptables" >&2
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F
    iptables -X 2>/dev/null || true
fi

if command -v nft >/dev/null 2>&1; then
    echo "hmv-example: flushing nft" >&2
    nft flush ruleset 2>/dev/null || true
fi

echo "hmv-example: firewall disabled (not persistent)" >&2
