#!/bin/bash
# HMV example script: free disk space.
#
# USE CASE
#   The server is out of disk (full /tmp, runaway logs, old kernels) and can no
#   longer do its job. HMV still runs via cron, so you sign and publish this
#   script as a source; the server runs it and reclaims space.
#
# HOW IT WORKS
#   Safe-by-default cleanups: package caches, rotated logs, journal vacuum,
#   old temporary files, and old kernels on Debian/Ubuntu. Nothing that is
#   clearly live config or user data is touched.
#
# RUN AT YOUR OWN RISK
#   It deletes files. Old kernels are removed only through the system package
#   manager's autoremove, never manually.

echo "hmv-example: freeing disk" >&2
df -h / 2>/dev/null | sed -n '1,2p' >&2

# package manager caches
if command -v apt-get >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get clean
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y 2>/dev/null || true
elif command -v dnf >/dev/null 2>&1; then
    dnf clean all 2>/dev/null || true
elif command -v yum >/dev/null 2>&1; then
    yum clean all 2>/dev/null || true
elif command -v apk >/dev/null 2>&1; then
    apk cache clean 2>/dev/null || true
fi

# journals and old compressed logs
if command -v journalctl >/dev/null 2>&1; then
    journalctl --vacuum-time=3d 2>/dev/null || true
fi
find /var/log -type f \( -name '*.gz' -o -name '*.1' -o -name '*.old' \) -delete 2>/dev/null || true

# stale temporary files (older than 7 days)
find /tmp -type f -mtime +7 -delete 2>/dev/null || true

echo "hmv-example: disk after cleanup:" >&2
df -h / 2>/dev/null | sed -n '1,2p' >&2
