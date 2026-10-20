#!/bin/bash
############### HMV ###############

# sources to fetch scripts from; one "type|location" entry per source.
# types: http (single file via wget/curl), git (shallow clone), rsync (dir over ssh)
# for rsync use a trailing slash to fetch a dir's contents
SOURCES=(
    # "http|https://example.com/hmv/script1.sh.gpg"
    # "git|https://git.example.com/hmv-scripts.git"
    # "rsync|operator@host:/opt/hmv-drop/"
)

DOWNDIR=$(mktemp -d) || exit 1


#
#   CLEANUP FUNCTIONS
#

cleanup () {
    [ -n "$DOWNDIR" ] || return 0
    rm -rf -- "$DOWNDIR"
    [ -e "$DOWNDIR" ] && echo "hmv: could not remove $DOWNDIR" >&2
}
# the EXIT trap covers normal end, `exit`, `set -e` aborts and `cd` failure;
# the signal traps route signals through exit so the EXIT trap runs too
# (SIGKILL cannot be trapped)
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
trap 'exit 131' QUIT
trap 'exit 141' PIPE


#
#   DOWNLOAD FUNCTIONS
#

fetch_http () {
    local url=$1
    if command -v wget >/dev/null 2>&1; then
        wget -q -P "$DOWNDIR" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$DOWNDIR/$(basename "${url%%\?*}")" "$url"
    else
        echo "hmv: neither wget nor curl available for $url" >&2
        return 1
    fi
}

fetch_git () {
    local name
    name=$(basename "$1" .git)
    git clone --depth 1 --quiet "$1" "$DOWNDIR/$name"
}

fetch_rsync () {
    rsync -a --quiet "$1" "$DOWNDIR"/
}


## 1) Download files

for src in "${SOURCES[@]}"; do
    type=${src%%|*}
    loc=${src#*|}
    case "$type" in
        http)  fetch_http "$loc"  || echo "hmv: source failed: $src" >&2 ;;
        git)   fetch_git "$loc"   || echo "hmv: source failed: $src" >&2 ;;
        rsync) fetch_rsync "$loc" || echo "hmv: source failed: $src" >&2 ;;
        *)     echo "hmv: unknown source type: $src" >&2 ;;
    esac
done


## 2) Move into the download directory
cd "$DOWNDIR" || exit 1


## 3) Verify, extract and run the signed scripts
# trust anchor is gpg's own keyring: VALIDSIG is only emitted when the
# signature is good AND the signing key is known to gpg (public key imported)
# each found .gpg is processed immediately; files are not revisited, and
# anything left behind is removed by the DOWNDIR cleanup at exit
while IFS= read -r -d '' f; do
    # signed-only file: --verify emits VALIDSIG if the signature is good.
    # encrypted files never produce VALIDSIG here (no decryption is done).
    if ! gpg --batch --status-fd 1 --verify "$f" 2>/dev/null \
            | grep -q '^\[GNUPG:\] VALIDSIG '; then
        echo "hmv: $f: not signed by a key known to gpg, skipping" >&2
        rm $f
        continue
    fi
    out=${f%.gpg}
    if ! gpg --batch --yes --output "$out" --decrypt "$f" 2>/dev/null; then
        echo "hmv: $f: failed to extract, skipping" >&2
        rm $f
        continue
    fi
    if ! LC_ALL=C file -b --mime-type "$out" | grep -qx 'text/x-shellscript'; then
        echo "hmv: $out: not a shell script, skipping" >&2
        continue
    fi
    if ! bash "$out"; then
        echo "hmv: $out: exited with error, skipping" >&2
    fi
done < <(find . -type f -name '*.gpg' -print0)


## 4) Clean and exit
# DOWNDIR removal is handled by the EXIT trap, so it also runs on errors/signals
