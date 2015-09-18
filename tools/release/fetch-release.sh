#!/bin/sh
#
# $Id$
#

trap 'exit' 1 2 3 4 5 6 7 8 9 10 11
while ! rsync --progress --partial --time-limit=5 -avH --delete rsync://releng1.nyi.freebsd.org/releases /snap/stage/releases; do :; done
find /snap/stage/releases/ -type d | xargs chmod 775

#echo "sync done" | mail -s "RELEASE FTP sync done" gjb@FreeBSD.org

