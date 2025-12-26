# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2025-12-26

### Added
- Automatic port conflict detection in monitoring setup
- Documentation for LiveKit port 9090 conflict resolution
- SSH config example for custom key names
- Comprehensive security audit report (AUDIT.md)
- LiveKit deployment guide (LIVEKIT_SETUP_GUIDE.md)

### Changed
- Updated README with LiveKit port conflict warning
- Improved monitoring setup documentation
- Enhanced idempotency across all scripts

### Fixed
- Port 9090 conflict when LiveKit Ingress is running
- Prometheus now can use alternative port (9091) when needed
- SSH key authentication with custom key names

### Security
- All scripts now fully idempotent (can be run multiple times safely)
- Backup configuration file permissions hardened to 600
- Backup scripts permissions set to 700 (root only)
- SSH configuration updates use helper functions to prevent duplicates
- fail2ban configuration checks for existing files before overwriting

## [1.0.0] - 2025-12-26

### Added
- Initial release
- Interactive setup wizard
- Firewall configuration with UFW
- LiveKit WebRTC server port presets
- Monitoring stack (Prometheus + Grafana + Node Exporter)
- Automated backup system with rotation
- Security hardening (fail2ban, SSH, automatic updates)
- Comprehensive documentation and audit report

### Features
- 🔒 Idempotent firewall rules management
- 📊 Docker-based monitoring with persistent volumes
- 💾 Scheduled backups with configurable retention
- 🛡️ CIS Ubuntu benchmark compliance
- 🔧 Helper scripts for common maintenance tasks
- ♻️ All scripts safe to re-run multiple times

---

## Release Notes

### Version 1.0.1
This update focuses on production deployment compatibility, especially for LiveKit WebRTC servers. Key improvements include automatic port conflict detection and comprehensive documentation for common deployment scenarios.

### Version 1.0.0
First production-ready release of VPS Operations Toolkit. Tested on Ubuntu 22.04 and 24.04 LTS with LiveKit deployment scenario.

---

**Production Status:** ✅ Ready for production use
**Last Updated:** 2025-12-26
