# NOTE THIS IS ALL IN BETA, don't use


# His Master's Voice

*His Master's Voice*  (HMV) is a remote administration tool made by a set of bash scripts.
The objective is to send scripts to be executed on remote machines, some sort of poor's man ansible.
Remember when you locked yourself out of a VPS instance because you lounched the firewall with the wrong settings? That's the case


## Requirements
  * bash for script execution
  * GPG for authentication and encryption
  * cron to launch HMV

## How it works

  * HMV is launched via cron and bash
  * downloads one or more sets of files from configured sources
     * sources can be git, wget/http(s), email...
  * files are saved into a temporary folder
  * files are checked against digital signatures
  * only scripts with recognized signatures will be executed. 
      * optionally scripts might be encrypted
  * scripts are then passed to bash for execution

## Setup

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

- upload the key to remote server
- install gpg on remote
- import the public key in remote's gpg
``` bash
gpg --import key.gpg # to import from bianry key, otherwise
gpg --import key.asc # to import ascii key
```

- download hvm
```bash
cd /opt
mkdir hmv
git clone ....

```

- install hmv
```bash
./install.sh
```

## Usage

- create a script and test it ```script.sh```
- sign the script with gpg
```bash
gpg -s script.sh
```
- **optional**: encrypt the script for the recipient

```bash
gpg -s -r <RECIPIENT> secret.txt
```

- gpg will generate a new file ```script.sh.gpg```

**NOTE**: the file name **MUST** end in ```.gpg```
- check the signed file:
```bash
gpg -d script.sh.gpg
```
- should output the script contents and the signature



- upload / drop the ```script.sh.gpg``` where the remote server