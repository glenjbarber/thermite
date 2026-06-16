# thermite.sh

FreeBSD Release Engineering build tools.

## What this is

Thermite was production release-engineering automation used to coordinate FreeBSD release and snapshot builds across multiple branches, architectures, kernels, and image formats.

It was designed around FreeBSD build infrastructure, ZFS datasets, chroots, and release/release.sh.
The goal was to reduce manual release work, keep build environments reproducible, stage artifacts consistently, generate checksums, and support publication/announcement workflows.

This repository was converted from a filtered Subversion history, so some layout and assumptions reflect the original FreeBSD infrastructure.

## Engineering highlights

- Config-driven build matrix across release branches, architectures, kernels, and build types
- ZFS snapshot/clone workflow for clean, reproducible build roots
- Chroot bootstrap and reuse for architecture-specific builds
- Artifact staging for FTP-style publication
- SHA256/SHA512 checksum generation for ISO and VM images
- Cloud image upload support
- Announcement email generation from build metadata
- Operational guardrails around publish steps
