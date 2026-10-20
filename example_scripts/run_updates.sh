#!/bin/bash
# HMV example script: run system updates.
#
# USE CASE
#   You want a server patched without logging in. HMV still runs via cron, so
#   you sign and publish this script as a source; the server runs it and applies
#   available updates on the next cron run.
#
# HOW IT WORKS
#   Detects the package manager and applies updates unattended:
#     apt-get update && apt-get upgrade -y    (Debian/Ubuntu)
#     dnf upgrade -y / yum update -y          (Fedora/RHEL)
#     apk upgrade                             (Alpine)
#
# RUN AT YOUR OWN RISK
#   Upgrading can restart services or require a reboot. Kernel or core-library
#   upgrades take effect only after a reboot, which this script does NOT do,
#   so a server you cannot reach is not rebooted out from under you.

echo "hmv-example: running updates" >&2

if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get -y upgrade
elif command -v dnf >/dev/null 2>&1; then
    dnf -y upgrade
elif command -v yum >/dev/null 2>&1; then
    yum -y update
elif command -v apk >/dev/null 2>&1; then
    apk update && apk upgrade
else
    echo "hmv-example: no known package manager, nothing to do" >&2
    exit 1
fi

echo "hmv-example: updates finished" >&2
