#!/bin/sh
#
# $FreeBSD$
#

hn=$(hostname | tr A-Z a-z)
me=$(id -un)

if [ "${hn}" != "ftp-master.freebsd.org" ]; then
	echo "For use on ftp-master only."
	exit 1
fi

if [ "x${me}" != "xarchive" ]; then
	echo "Must be run by the 'archive' user."
	exit 1
fi

#cd /archive/tmp/releases
#pax -r -w -l . /archive/pub/FreeBSD/releases
#/usr/local/bin/rsync -avH /archive/tmp/releases/* /archive/pub/FreeBSD/releasees/

cd /archive/tmp/snapshots
pax -r -w -l . /archive/pub/FreeBSD/snapshots
/usr/local/bin/rsync -avH /archive/tmp/snapshots/* /archive/pub/FreeBSD/snapshots/
