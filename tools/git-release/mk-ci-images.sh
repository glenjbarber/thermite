#!/bin/sh

# Usage
if [ $# -ne 1 ]; then
	echo "usage: mk-ci-images.sh 13"
	exit 1
fi
BR=$1

# Get snapshot details rom the amd64 SHA256 checksum file
CSUMF=`echo /releng/$BR-amd64-GENERIC-snap/R/ftp-stage/snapshots/amd64/amd64/ISO-IMAGES/*/CHECKSUM.SHA256-* | cut -f 11 -d /`
VER=`echo $CSUMF | cut -f 3-4 -d -`
DATE=`echo $CSUMF | cut -f 6 -d -`
GHASH=`echo $CSUMF | cut -f 7 -d -`
CNUM=`echo $CSUMF | cut -f 8 -d -`

# Make sure we actually got them
if [ -z "$VER" ] || [ -z "$DATE" ] ||
    [ -z "$GHASH" ] || [ -z "$CNUM" ]; then
	echo "Cannot find amd64 CHECKSUM.256 file"
	exit 1
fi

# Create CI-IMAGES bits in the ftp-stage directory
mkdir -p /releng/$BR-amd64-GENERIC-snap/R/ftp-stage/snapshots/CI-IMAGES/$VER/amd64/$DATE
mkdir -p /releng/$BR-amd64-GENERIC-snap/R/ftp-stage/snapshots/CI-IMAGES/$VER/amd64/Latest
cp -p /releng/$BR-amd64-GENERIC-snap/usr/obj/usr/src/amd64.amd64/release/basic-ci.raw \
    /releng/$BR-amd64-GENERIC-snap/R/ftp-stage/snapshots/CI-IMAGES/$VER/amd64/$DATE
cd /releng/$BR-amd64-GENERIC-snap/R/ftp-stage/snapshots/CI-IMAGES/$VER/amd64/$DATE
xz -T0 basic-ci.raw
mv basic-ci.raw.xz FreeBSD-$VER-amd64-BASIC-CI-$DATE-$GHASH-$CNUM.raw.xz
sha256 F* > CHECKSUM.SHA256-$DATE-$GHASH-$CNUM
sha512 F* > CHECKSUM.SHA512-$DATE-$GHASH-$CNUM
ln -s ../$DATE/FreeBSD-$VER-amd64-BASIC-CI-$DATE-$GHASH-$CNUM.raw.xz \
    ../Latest/FreeBSD-$VER-amd64-BASIC-CI.raw.xz
ln -s ../$DATE/CHECKSUM.SHA256-$DATE-$GHASH-$CNUM ../Latest/CHECKSUM.SHA256
ln -s ../$DATE/CHECKSUM.SHA512-$DATE-$GHASH-$CNUM ../Latest/CHECKSUM.SHA512
rsync -avH /releng/$BR-amd64-GENERIC-snap/R/ftp-stage/snapshots/CI-IMAGES/* \
    /snap/ftp/snapshots/CI-IMAGES

