#!/bin/sh

mkdir /mnt/gitester
mkdir /mnt/gitester/dev
mkdir /mnt/gitester/proc
mkdir /mnt/gitester/bin
mkdir /mnt/gitester/lib
mkdir /mnt/gitester/usr/bin
mkdir /mnt/gitester/usr/lib

mount --bind /dev     /mnt/gitester/dev
mount --bind /proc    /mnt/gitester/proc
mount --bind /bin     /mnt/gitester/bin
mount --bind /lib     /mnt/gitester/lib
mount --bind /usr/bin /mnt/gitester/usr/bin
mount --bind /usr/lib /mnt/gitester/usr/lib

# make non-root chroot
chroot /mnt/gitester

wget $1 -o project
wget $2 -o tests

./project/deploy.sh
./tests/test.sh
