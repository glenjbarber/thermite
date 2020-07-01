#!/bin/sh
#
# $FreeBSD$
#

mkdir -p /archive/tmp/snapshots
/usr/local/bin/rsync --progress -avH rsync://releng1.nyi.freebsd.org/snapshots /archive/tmp/snapshots
/usr/local/bin/rsync --progress -avH rsync://releng2.nyi.freebsd.org/snapshots /archive/tmp/snapshots
/usr/local/bin/rsync --progress -avH rsync://releng3.nyi.freebsd.org/snapshots /archive/tmp/snapshots

#mkdir -p /archive/tmp/releases
#/usr/local/bin/rsync --progress -avH rsync://releng1.nyi.freebsd.org/releases /archive/tmp/releases
#/usr/local/bin/rsync --progress -avH rsync://releng2.nyi.freebsd.org/releases /archive/tmp/releases
#/usr/local/bin/rsync --progress -avH rsync://releng3.nyi.freebsd.org/releases /archive/tmp/releases
