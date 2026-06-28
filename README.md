# thermite.sh

FreeBSD Release Engineering build tools.

## What This Is

Thermite is a configuration-driven release orchestration system built around the native `release/release.sh` tooling in FreeBSD.

It manages the broader release workflow across multiple architectures and targets, including ZFS-based build environments, artifact staging, centralized logging, completion and failure notifications, and cloud image publication.

Its purpose is to make complex FreeBSD release builds more repeatable, observable, and easier to operate without relying on manual command sequences or institutional memory.

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
