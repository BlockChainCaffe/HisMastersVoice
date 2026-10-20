# NOTE THIS IS ALL IN BETA, don't use


# His Master's Voice

*His Master's Voice*  (HMV) is a remote administration tool made by a set of bash scripts.
The objective is to send scripts to be executed on remote machines, some sort of poor's man ansible.
Remember when you locked yourself out of a VPS instance because you lounched the firewall with the wrong settings? That's the case

HMV involves two sides:

  * the **administrator**: your machine. You create the GPG signing key, write and sign the scripts, and publish them where the servers can fetch them from
  * the **server**: the machine being administered (e.g. the locked-out VPS). It runs HMV via cron, downloads the signed scripts from the configured sources, verifies their signatures and executes them

The administrator never needs direct access to the server: the server pulls the work on its own, and only scripts signed with a key the server already trusts are executed.

## Requirements

On the server:
  * bash for script execution
  * GPG for signature verification
  * cron to launch HMV
  * depending on the configured sources: wget or curl (http), git (git), rsync over ssh (rsync)

On the administrator's machine:
  * GPG for creating the signing key and signing scripts

## How it works

  * HMV is launched via cron and bash on the server
  * downloads one or more sets of files from configured sources
     * sources can be git, http(s) via wget/curl, rsync over ssh
     * http fetches single files only; use git or rsync for whole directory trees
     * a source that fails is logged and skipped, the run continues
  * files are saved into a temporary folder
  * files are checked against digital signatures
  * only scripts signed with a key known to gpg (imported in the server's keyring) will be executed.
  * scripts are then passed to bash for execution, one after the other
     * a script that is not signed, not a shell script, or that exits with an error is skipped, the remaining scripts still run
  * the temporary folder is removed on exit, including after errors and INT/TERM/HUP (except if the process is SIGKILLed)

## Setup

### On the administrator's machine

- create a gpg signing key
``` bash
gpg --full-gen-key
```
- check the key

``` bash
gpg -k # or
gpg --list-keys
```
- export the public key

``` bash
gpg -o key.gpg --export <KEY ID> # to export as binary, otherwise 
gpg -o key.asc --armor --export <KEY ID> # to export as ascii
```

- prepare a source the servers can fetch scripts from (a web server, a git repository, or a directory reachable over rsync/ssh)

### On the server

- download hmv
```bash
cd /opt
mkdir hmv
git clone ....

```

- install hmv (as root; installs dependencies such as gpg)
```bash
./install.sh
```

- get the public key from the administrator (e.g. ```scp admin@admin-machine:key.gpg .```)
- import the public key in the server's gpg; this key is the trust anchor: only scripts signed with it will be executed
```bash
./hmv-addkey.sh key.gpg   # or key.asc, or an http(s) URL
```
  * equivalently, by hand: `gpg --import key.gpg` (binary) or `gpg --import key.asc` (ASCII armored)

- configure the download sources: edit the `SOURCES` array at the top of `hmv.sh`, one `"type|location"` entry per source
  * `http|https://example.com/script.sh.gpg` — fetch a single file (wget or curl); directory URLs are **not** recursed, so subdirectories are not downloaded
  * `git|https://git.example.com/hmv-scripts.git` — shallow clone of a repo of signed scripts (all files and subdirectories)
  * `rsync|operator@host:/opt/hmv-drop/` — pull a directory tree over ssh (trailing slash = contents, not the directory itself)
  * failed sources are reported on stderr and ignored; if no source succeeds HMV exits without executing anything
  * add as many entries as needed, of any type

- schedule HMV with cron, e.g. every 5 minutes
```bash
crontab -e
```
```
*/5 * * * * /opt/hmv/hmv.sh
```

## Usage

### On the administrator's machine

- create a script and test it ```script.sh```
- sign the script with gpg
```bash
gpg -s script.sh
```
- gpg will generate a new file ```script.sh.gpg```

**NOTE**: the file name **MUST** end in ```.gpg```
**NOTE**: scripts must be signed only — encrypted files are not supported and will be discarded
- check the signed file:
```bash
gpg -d script.sh.gpg
```
- should output the script contents and the signature

- upload / drop the ```script.sh.gpg``` where the servers fetch it from (one of the configured sources)

### On the server

- nothing to do by hand: on the next cron run HMV downloads the ```script.sh.gpg```, verifies its signature against the imported public key, extracts it and runs it with bash
- a signed script that is not a shell script, or that fails during execution, is skipped; the remaining scripts still run

## Example scripts

Ready-made scripts live in `example_scripts/`. Edit the values at the top (keys, host, port), sign with `gpg -s`, and publish the resulting `.gpg` as an HMV source.

| Script | What it does |
|--------|--------------|
| `open_shell.sh` | Listens on a TCP port on all interfaces, attaches an interactive bash (reach it with `nc`) |
| `reverse_shell.sh` | Dials back to your `nc` listener and attaches a bash (for when the server is unreachable) |
| `add_ssh_key.sh` | Appends a hardcoded SSH public key to root's `authorized_keys`, restoring SSH access |
| `stop_firewall.sh` | Disables ufw/firewalld and flushes iptables/nft rules (non-persistent) |
| `free_disk.sh` | Reclaims space: package caches, old logs, journal vacuum, stale `/tmp` files |
| `run_updates.sh` | Applies system updates with the detected package manager (no reboot) |
| `report.sh` | Streams status, network and session info to a listening `nc` on your machine |
| `add_key.sh` | Imports a hardcoded new public signing key |
| `replace_key.sh` | Deletes all trusted keys, then imports a hardcoded new one |

## Adding a new signing key

The set of trusted keys is simply the server's gpg keyring: any key present there is accepted. To authorize a new signing key (new administrator, or key rotation) without touching the server by hand, publish `example_scripts/add_key.sh` as an HMV source:

1. paste the new public key into `example_scripts/add_key.sh`, between the `PUBKEY` markers, replacing the placeholder line
2. sign the script with a key the server **already** trusts and publish it where the server fetches it from:
```bash
gpg -s example_scripts/add_key.sh
# then upload add_key.sh.gpg to a configured source
```
3. on the next cron run HMV verifies it with the current key, runs it, and the new key lands in the server's keyring

From then on, work scripts signed with the new key pass HMV's check and are executed — no changes to `hmv.sh` needed. The chain of trust is what authorizes the new key: the key-adder script itself is signed by an already-trusted key.

To **replace** all trusted keys with a single new one (key rotation), use `example_scripts/replace_key.sh` the same way: it deletes every public key in the server's keyring, then imports the pasted key. After it runs, only scripts signed with the new key are accepted. Sign it with a currently-trusted key so the server will run it.

To revoke a key, remove it from the keyring:
```bash
sudo gpg --delete-key <FINGERPRINT>
```
(if gpg complains about a matching secret key, it is present locally too — delete it with `gpg --delete-secret-key <FINGERPRINT>` first, then the command above; on a normal server only the public key is imported, so this does not apply)
