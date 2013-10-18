#
# $FreeBSD: scripts/Makefile 121 2013-02-02 05:58:31Z gjb $
# $relengid$
#
# User driven targets:
# setup:	Create the filesystem hierarchy for snapshots, and check out
# 		source trees to necessary locations.
#
# cleanup:	Remove .OBJDIR from previous builds.
#
# cleanup-all:	Remove filesystem hierarchy created with setup target.
#

SH=		/bin/sh
MKDIR=		/bin/mkdir
MKDIR_FLAGS?=	-p -m755

RM=		/bin/rm
RMFLAGS?=	-fr

CHFLAGS=	/bin/chflags
CHFLAGS_FLAGS?=	-R noschg
SVN?=		/usr/local/bin/svn
RELSRC?=	/usr/src/release

.if(!exists(${SVN}))
. error "svn(1) is not installed, or not in PATH."
.endif

RELDIR?=	/snap/releng

ARCHS?=		amd64 i386 powerpc powerpc64
HEAD?=		10
STABLE?=	9
REVS?=		${HEAD} ${STABLE}
SRCDIRS?=	usr/src usr/ports usr/doc
OBJDIR?=	usr/obj

SVNSRC?=	svn://svn.freebsd.org
EXSRCS?=	doc ports

HEADBRANCH?=	base/head
STABLEBRANCH?=	base/stable

SVNREV!=	cat svnrev.txt

default:

setup:
.if(!exists(${RELDIR}))
	@(${MKDIR} ${MKDIR_FLAGS} ${RELDIR})
.endif
