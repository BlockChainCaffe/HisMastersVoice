#!/bin/bash
# HMV example script: add a new public key to the trusted keyring.
#
# USE CASE
#   You (the administrator) want to authorize a new signing key on a server, so
#   that scripts signed with it are accepted and executed. You sign and publish
#   THIS script as an HMV source; the server runs it on the next cron run and
#   imports the public key into its gpg keyring (the trust anchor).
#
# HOW IT WORKS
#   The public key is hardcoded below: paste the ASCII-armored key between the
#   PUBKEY markers, sign this script with a key the server ALREADY trusts, and
#   publish it. On the next cron run HMV runs it and the key is imported. After
#   that, scripts signed with the new key are verified and executed.
#
#   This very script must itself be signed with an already-trusted key — that is
#   the chain of trust that authorizes the new one.
#
# RUN AT YOUR OWN RISK
#   Importing a key means trusting every script signed with it from now on.
#   Only paste a key you control.

gpg --batch --import <<'PUBKEY'
-----BEGIN PGP PUBLIC KEY BLOCK-----

PASTE YOUR PUBLIC KEY HERE

-----END PGP PUBLIC KEY BLOCK-----
PUBKEY
