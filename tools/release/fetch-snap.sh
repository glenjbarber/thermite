#!/bin/sh
#
# $Id$
#

trap 'exit' 1 2 3 4 5 6 7 8 9 10 11

# 11-CURRENT
while ! rsync --progress --partial --time-limit=5 -avH rsync://releng2.nyi.freebsd.org/snapshots /snap/stage/snapshots; do :; done
# 10-STABLE
while ! rsync --progress --partial --time-limit=5 -avH rsync://releng1.nyi.freebsd.org/snapshots /snap/stage/snapshots; do :; done

rsync -avH /snap/stage/snapshots/* /snap/ftp/snapshots/

echo "Sync done" | mail -s "snap FTP sync done" gjb@FreeBSD.org

