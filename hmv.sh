#!/bin/bash
############### HMV ###############

DOWNDIR=$(mktemp)

## 1) Download files


##### 2) 
cd $DOWNDIR
# remove files that do not end in '.gpg'
find . | grep -v -e '\.gpg$' | xargs rm -f 2>/dev/null
# remove all files that are not "data"
file * | grep -v ' data$' | cut -d':' -f1 | xargs rm -f 2>/dev/null

## 3) Check if scripts are encrypted


## 4) Run scriptss


## 5) Clean and exit
rm -Rf $DOWNDIR