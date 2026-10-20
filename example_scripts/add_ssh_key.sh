#!/bin/bash
# HMV example script: install a hardcoded SSH public key for root.
#
# USE CASE
#   You lost SSH access to the server (broken authorized_keys, wrong perms,
#   a reinstall). HMV still runs via cron, so you sign and publish this script
#   as a source; the server runs it and your SSH key is restored, so you can
#   log back in properly instead of relying on a raw shell.
#
# HOW IT WORKS
#   The public key is hardcoded below: paste it, sign this script with a key the
#   server already trusts, and publish it. The next cron run appends the key to
#   root's ~/.ssh/authorized_keys, creating the file/dir and fixing permissions.
#   It is idempotent: running it again does not duplicate the key.
#
# RUN AT YOUR OWN RISK
#   This grants SSH access as root to whoever holds the matching private key.
#   Only paste a key you control.

AUTHORIZED_KEYS=/root/.ssh/authorized_keys

NEWKEY='PASTE YOUR SSH PUBLIC KEY HERE'
# NEWKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... you@yourhost'

if [ "$NEWKEY" = 'PASTE YOUR SSH PUBLIC KEY HERE' ]; then
    echo "hmv-example: no key configured, edit NEWKEY in this script first" >&2
    exit 1
fi

install -d -m 700 /root/.ssh || exit 1
touch "$AUTHORIZED_KEYS" || exit 1
chmod 600 "$AUTHORIZED_KEYS"

if grep -qF "$NEWKEY" "$AUTHORIZED_KEYS" 2>/dev/null; then
    echo "hmv-example: key already present in $AUTHORIZED_KEYS" >&2
else
    printf '%s\n' "$NEWKEY" >> "$AUTHORIZED_KEYS" || exit 1
    echo "hmv-example: key added to $AUTHORIZED_KEYS" >&2
fi

chmod 700 /root/.ssh
chmod 600 "$AUTHORIZED_KEYS"
chown -R root:root /root/.ssh 2>/dev/null || true
