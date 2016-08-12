#!/bin/sh
# $Id$

hn=$(hostname | tr A-Z a-z)

if [ "${hn}" != "ftp-master.freebsd.org" ]; then
	exit 1
fi
cd /archive/tmp/releases
pax -r -w -l . /archive/pub/FreeBSD/releases
