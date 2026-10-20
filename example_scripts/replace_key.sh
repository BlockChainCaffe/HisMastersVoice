#!/bin/bash
# HMV example script: replace the trusted keyring with a new public key.
#
# USE CASE
#   You (the administrator) want to rotate the signing key: authorize a new key
#   and stop trusting the old one(s). You sign and publish THIS script as an
#   HMV source; the server runs it on the next cron run, wipes its gpg keyring
#   and imports the new public key.
#
# HOW IT WORKS
#   The public key is hardcoded below: paste the ASCII-armored key between the
#   PUBKEY markers. All existing public keys are deleted first (so keys signed
#   with them stop being accepted), then the new key is imported.
#
#   This very script must itself be signed with a key the server ALREADY trusts
#   — that is the chain of trust that authorizes the switch. After it runs, only
#   the new key is trusted.
#
# RUN AT YOUR OWN RISK
#   This drops your ability to run scripts signed with the old keys. Make sure
#   the new key works (or that you have a way back in) before publishing this.

# remove every public key currently in the keyring
existing=$(gpg --batch --with-colons --list-keys 2>/dev/null \
    | awk -F: '$1=="pub" { print $5 }')
for key in $existing; do
    echo "hmv-example: removing key $key" >&2
    gpg --batch --yes --delete-key "$key" 2>/dev/null \
        || echo "hmv-example: could not remove $key (secret key present?)" >&2
done

# import the new key
gpg --batch --import <<'PUBKEY'
-----BEGIN PGP PUBLIC KEY BLOCK-----

PASTE YOUR PUBLIC KEY HERE

-----END PGP PUBLIC KEY BLOCK-----
PUBKEY
