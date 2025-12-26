# VPS Operations Toolkit

A comprehensive, production-ready wizard for Ubuntu 22.04-24.04 VPS setup, security hardening, and maintenance.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20|%2024.04-orange.svg)](https://ubuntu.com/)

## Features

- 🔒 **Firewall Configuration** - Idempotent UFW setup with common service ports and LiveKit presets
- 📊 **Monitoring Stack** - Prometheus + Grafana + Node Exporter with Docker
- 💾 **Automated Backups** - Scheduled backups with rotation, compression, and secure storage
- 🛡️ **Security Hardening** - fail2ban, SSH hardening, automatic updates, and CIS compliance
- 🔧 **Interactive Wizard** - User-friendly setup with safety confirmations
- ♻️ **Idempotent Scripts** - Safe to run multiple times without side effects

## Compatibility

- **Ubuntu 22.04 LTS** (Jammy Jellyfish)
- **Ubuntu 24.04 LTS** (Noble Numbat)
- Requires root/sudo access
- Minimum 1GB RAM, 10GB disk space

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Duvet05/vps-ops-kit.git
cd vps-ops-kit

# Scripts already have execute permissions, but verify
chmod +x setup-wizard.sh scripts/*.sh

# Run the interactive setup wizard
sudo ./setup-wizard.sh

# Or run individual scripts
sudo ./scripts/setup-firewall.sh
sudo ./scripts/setup-monitoring.sh
sudo ./scripts/setup-backup.sh
sudo ./scripts/harden-security.sh
```

## 📋 Table of Contents

- [Components](#components)
- [Usage Examples](#usage-examples)
- [Configuration](#configuration-files)
- [Security](#security-best-practices)
- [Idempotency](#idempotency-guarantee)
- [File Permissions](#file-permissions)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)

---

## Components

### 1. 🔒 Firewall Configuration (`scripts/setup-firewall.sh`)

Configures UFW (Uncomplicated Firewall) with intelligent defaults:

**Features:**
- ✅ Idempotent rule management (no duplicates on re-run)
- ✅ Pre-configured LiveKit WebRTC server ports
- ✅ SSH lockout prevention
- ✅ Checks existing firewall configurations (UFW, iptables, firewalld)
- ✅ Interactive custom port configuration

**Default Ports:**
- SSH: 22/tcp
- HTTP: 80/tcp
- HTTPS: 443/tcp

**LiveKit Preset Ports:**
- WebRTC over TCP: 7881/tcp
- TURN/UDP: 3478/udp
- WebRTC UDP Range: 50000-60000/udp
- RTMP Ingress: 1935/tcp
- WHIP Ingress: 7885/udp

**Safety Features:**
- Detects active firewalls before proceeding
- Always allows SSH before enabling
- User confirmation for destructive operations
- Comprehensive logging

**Usage:**
```bash
sudo ./scripts/setup-firewall.sh
```

---

### 2. 📊 Monitoring Stack (`scripts/setup-monitoring.sh`)

Deploys a complete monitoring solution using Docker:

**Components:**
- **Prometheus** (port 9090 by default) - Metrics collection and storage
- **Grafana** (port 3000) - Visualization dashboards
- **Node Exporter** (port 9100) - System metrics

**Features:**
- ✅ Docker and Docker Compose auto-installation
- ✅ Pre-configured Prometheus data sources
- ✅ Idempotent container management
- ✅ Helper scripts for start/stop/logs
- ✅ Persistent data volumes
- ✅ Automatic port conflict detection

**Access:**
- Prometheus: `http://your-server:9090` (or custom port if configured)
- Grafana: `http://your-server:3000`
  - **Default credentials:** admin/admin
  - ⚠️ **CHANGE IMMEDIATELY AFTER FIRST LOGIN**

**⚠️ LiveKit Port Conflict:**
If you're running LiveKit, port 9090 is used by LiveKit Ingress. The monitoring stack will automatically detect this and fail. To fix:
```bash
# Change Prometheus port to 9091
sed -i 's/"9090:9090"/"9091:9090"/g' /opt/vps-monitoring/docker-compose.yml
cd /opt/vps-monitoring && docker compose down && docker compose up -d
# Allow the new port in firewall
ufw allow 9091/tcp comment 'Prometheus'
```

**Security Warnings:**
- Default Grafana password must be changed
- Consider using a reverse proxy with SSL/TLS
- Restrict access using firewall rules (UFW)
- Monitoring ports are exposed by default

**Usage:**
```bash
sudo ./scripts/setup-monitoring.sh

# After installation
cd /opt/vps-monitoring
./logs.sh    # View container logs
./stop.sh    # Stop monitoring stack
./start.sh   # Start monitoring stack
```

**Recommended Dashboards:**
- Node Exporter Full (ID: 1860)
- Prometheus 2.0 Stats (ID: 3662)

---

### 3. 💾 Backup System (`scripts/setup-backup.sh`)

Enterprise-grade automated backup solution:

**Features:**
- ✅ Configurable backup paths
- ✅ Automatic compression (gzip)
- ✅ Retention policy (configurable days)
- ✅ Docker volume backups
- ✅ MySQL/PostgreSQL database backups
- ✅ Cron job automation
- ✅ Idempotent cron setup (no duplicates)
- ✅ Secure file permissions (600 for configs)

**Default Backup Paths:**
- `/etc` - System configuration
- `/home` - User data
- `/root` - Root user data
- `/var/www` - Web applications
- `/opt` - Optional software

**Backup Location:** `/var/backups/vps/`

**Configuration:** `/opt/vps-backup/config/backup.conf`

**⚠️ Security Notes:**
- Configuration file contains database credentials
- File permissions automatically set to 600 (root only)
- Backups are NOT encrypted by default
- Consider GPG encryption for sensitive data

**Usage:**
```bash
sudo ./scripts/setup-backup.sh

# Manual backup
sudo /opt/vps-backup/backup.sh

# Restore from backup
sudo /opt/vps-backup/restore.sh
```

**Customization:**
```bash
# Edit backup configuration
sudo nano /opt/vps-backup/config/backup.conf

# Adjust retention policy, add databases, Docker volumes, etc.
```

---

### 4. 🛡️ Security Hardening (`scripts/harden-security.sh`)

Production-grade security implementation following CIS benchmarks:

**Features:**
- ✅ **fail2ban** - Intrusion prevention (SSH, DDOS protection)
- ✅ **SSH Hardening** - Strong ciphers, key-only auth, disabled root login
- ✅ **Automatic Security Updates** - Unattended upgrades for security patches
- ✅ **System Auditing** - auditd monitoring of critical files
- ✅ **Security Tools** - rkhunter, lynis for vulnerability scanning
- ✅ **Idempotent Configuration** - Safe to re-run
- ✅ **Automatic Backups** - SSH config backed up before changes

**SSH Security Settings:**

**Basic Hardening:**
- PermitRootLogin: prohibit-password
- PasswordAuthentication: optional (user prompted)
- PermitEmptyPasswords: no
- MaxAuthTries: 3

**Full Hardening (Advanced):**
- X11Forwarding: no
- LoginGraceTime: 30 seconds
- MaxSessions: 2
- Strong ciphers only (ChaCha20, AES-GCM)
- Strong MACs (SHA2-512, SHA2-256)
- Modern key exchange algorithms (Curve25519)

**fail2ban Configuration:**
- Ban time: 1 hour (3600s)
- Max retry: 3 attempts
- Find time: 10 minutes (600s)
- SSH and SSH-DDOS protection enabled

**⚠️ Critical Safety:**
- SSH config is backed up before modification
- Configuration is tested before applying
- User must confirm before disabling password auth
- Requires console access for safety

**Usage:**
```bash
sudo ./scripts/harden-security.sh

# View security report
sudo cat /var/log/vps-ops-kit/security-report-*.txt

# Check fail2ban status
sudo fail2ban-client status

# Run security scan
sudo rkhunter --check
sudo lynis audit system
```

---

### 5. 🧙 Interactive Wizard (`setup-wizard.sh`)

Guided setup process for all components:

**Features:**
- Menu-driven interface
- Runs individual scripts
- Comprehensive logging
- Error handling

**Usage:**
```bash
sudo ./setup-wizard.sh
```

---

## Usage Examples

### Complete VPS Setup (Recommended Order)

```bash
# 1. Clone and setup
git clone https://github.com/Duvet05/vps-ops-kit.git
cd vps-ops-kit

# 2. Security hardening FIRST
sudo ./scripts/harden-security.sh

# 3. Firewall configuration
sudo ./scripts/setup-firewall.sh

# 4. Monitoring stack
sudo ./scripts/setup-monitoring.sh

# 5. Backup system
sudo ./scripts/setup-backup.sh
```

### Re-running Scripts (Idempotency)

All scripts are idempotent and can be safely re-run:

```bash
# Add new firewall rules without duplicates
sudo ./scripts/setup-firewall.sh

# Update monitoring stack
sudo ./scripts/setup-monitoring.sh

# Reconfigure backups
sudo ./scripts/setup-backup.sh
```

---

## Configuration Files

### System Locations

| Component | Location | Permissions | Owner |
|-----------|----------|-------------|-------|
| Firewall Config | `/etc/vps-ops-kit/firewall.conf` | 644 | root:root |
| Backup Config | `/opt/vps-backup/config/backup.conf` | **600** | root:root |
| Backup Scripts | `/opt/vps-backup/` | 700 | root:root |
| Monitoring | `/opt/vps-monitoring/` | 755 | root:root |
| Logs | `/var/log/vps-ops-kit/` | 755 | root:root |

### Backup Configuration

Edit `/opt/vps-backup/config/backup.conf`:

```bash
# Backup retention
RETENTION_DAYS=7

# Add custom paths
BACKUP_PATHS=(
    "/etc"
    "/home"
    "/your/custom/path"
)

# Docker volumes
BACKUP_DOCKER=true
DOCKER_VOLUMES=(
    "my-app-data"
    "postgres-data"
)

# MySQL databases
BACKUP_MYSQL=true
MYSQL_USER="backup_user"
MYSQL_PASSWORD="secure_password"  # ⚠️ Sensitive!
MYSQL_DATABASES=("mydb" "another_db")
```

**⚠️ Important:** This file contains sensitive credentials and is secured with 600 permissions.

---

## Security Best Practices

### 🔴 Critical Security Steps

1. **Change Default Passwords**
   - Grafana: Change admin/admin immediately
   - Database credentials in backup.conf

2. **SSH Key Authentication**
   - Generate SSH keys before disabling password auth
   - Keep backup access method available

3. **Firewall Configuration**
   - Only expose necessary ports
   - Use IP whitelisting where possible
   - Monitor fail2ban logs regularly

4. **Backup Security**
   - Secure `/opt/vps-backup/config/backup.conf` (done automatically)
   - Consider encrypting backup files
   - Test restores regularly
   - Store backups off-site

5. **Monitoring Access**
   - Use reverse proxy with SSL/TLS
   - Restrict Grafana/Prometheus access
   - Enable authentication on Prometheus

### CIS Benchmark Compliance

This toolkit implements several CIS Ubuntu benchmarks:
- ✅ **5.2.x** - SSH Server Configuration
- ✅ **3.5.x** - Firewall Configuration
- ✅ **1.8** - Ensure updates, patches, and additional security software are installed
- ✅ **4.1.x** - Audit logging (auditd)

---

## Idempotency Guarantee

All scripts are designed to be **idempotent** - they can be run multiple times safely:

### What Idempotency Means

- ✅ No duplicate firewall rules
- ✅ No duplicate cron jobs
- ✅ No duplicate SSH config settings
- ✅ Preserves existing configurations
- ✅ User prompts before overwriting

### How It Works

**Firewall:**
```bash
# Checks if rule exists before adding
if ! rule_exists "80/tcp"; then
    ufw allow 80/tcp
fi
```

**Backup:**
```bash
# Checks for existing cron job
if crontab -l | grep -q "backup.sh"; then
    # Ask to update
fi
```

**Security:**
```bash
# Removes old setting, adds new (no duplicates)
update_ssh_setting "PermitRootLogin" "no"
```

---

## File Permissions

### Script Permissions

All scripts have execute permissions:
```bash
-rwx--x--x setup-wizard.sh
-rwx--x--x scripts/setup-firewall.sh
-rwx--x--x scripts/setup-monitoring.sh
-rwx--x--x scripts/setup-backup.sh
-rwx--x--x scripts/harden-security.sh
```

### Security-Critical Files

The following files have restricted permissions for security:

```bash
# Backup configuration (contains DB passwords)
600 root:root /opt/vps-backup/config/backup.conf

# Backup scripts (root only)
700 root:root /opt/vps-backup/backup.sh
700 root:root /opt/vps-backup/restore.sh

# SSH configuration backup
600 root:root /etc/ssh/sshd_config.backup.*
```

---

## Troubleshooting

### Common Issues

#### 1. SSH Lockout After Hardening

**Symptoms:** Cannot SSH into server after running security hardening

**Solutions:**
```bash
# Access via console (VPS provider dashboard)
# Restore SSH backup
sudo cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config
sudo systemctl restart sshd
```

**Prevention:**
- Keep a console access window open
- Test SSH in new terminal before closing existing connection
- Ensure SSH keys are configured before disabling password auth

#### 2. Firewall Blocking Access

**Symptoms:** Cannot access services after enabling UFW

**Solutions:**
```bash
# Disable firewall temporarily
sudo ufw disable

# Check rules
sudo ufw status numbered

# Delete problematic rule
sudo ufw delete [number]

# Re-enable
sudo ufw enable
```

#### 3. Monitoring Stack Won't Start

**Symptoms:** Docker containers fail to start

**Solutions:**
```bash
# Check Docker status
sudo systemctl status docker

# View container logs
cd /opt/vps-monitoring
./logs.sh

# Restart stack
./stop.sh && ./start.sh

# Check port conflicts
sudo ss -tlnp | grep -E '3000|9090|9100'
```

#### 4. Backup Script Fails

**Symptoms:** Backup script exits with errors

**Solutions:**
```bash
# Check logs
sudo tail -f /var/log/vps-ops-kit/backup-*.log

# Verify disk space
df -h

# Test backup configuration
sudo /opt/vps-backup/backup.sh

# Check permissions
ls -la /opt/vps-backup/
```

### Log Locations

All scripts log to `/var/log/vps-ops-kit/`:

```bash
firewall-setup.log
monitoring-setup.log
backup-setup.log
security-hardening.log
backup-YYYYMMDD.log
security-report-YYYYMMDD.txt
```

---

## Testing

### Recommended Testing Procedure

1. **Test in staging environment first**
2. **Create VM snapshot before running scripts**
3. **Run scripts individually**
4. **Verify each component works**
5. **Test idempotency by re-running**

### Idempotency Testing

```bash
# Run each script twice and verify no errors
sudo ./scripts/setup-firewall.sh
sudo ./scripts/setup-firewall.sh  # Should skip existing rules

sudo ./scripts/setup-backup.sh
sudo ./scripts/setup-backup.sh  # Should detect existing config

sudo ./scripts/harden-security.sh
sudo ./scripts/harden-security.sh  # Should preserve settings
```

---

## Roadmap

### Current Version: 1.0.0

- [x] Idempotent script design
- [x] Comprehensive security hardening
- [x] Docker-based monitoring
- [x] Automated backup system
- [x] LiveKit port presets
- [x] Comprehensive documentation

### Planned Features

- [ ] SSL/TLS certificate automation (Let's Encrypt)
- [ ] Reverse proxy setup (Nginx/Traefik)
- [ ] Backup encryption (GPG)
- [ ] Remote backup to S3/B2
- [ ] Multi-VPS orchestration
- [ ] Web-based configuration interface
- [ ] Automated testing (BATS)
- [ ] Additional monitoring integrations
- [ ] Log aggregation (ELK/Loki)
- [ ] Container security scanning

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test thoroughly (idempotency!)
4. Follow shell scripting best practices
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

## License

MIT License - See [LICENSE](LICENSE) file for details.

---

## Support

### Getting Help

- **Issues:** [GitHub Issues](https://github.com/Duvet05/vps-ops-kit/issues)
- **Documentation:** [GitHub Wiki](https://github.com/Duvet05/vps-ops-kit/wiki)
- **Discussions:** [GitHub Discussions](https://github.com/Duvet05/vps-ops-kit/discussions)

### Reporting Security Issues

Please report security vulnerabilities privately to the repository maintainer.

---

## Credits

Created for Ubuntu VPS administrators who want a reliable, safe, and automated operations toolkit.

**Built with:**
- Bash
- UFW
- fail2ban
- Docker & Docker Compose
- Prometheus
- Grafana

**Inspired by:**
- CIS Ubuntu Benchmarks
- OWASP Infrastructure Security
- DevOps best practices

---

## Disclaimer

⚠️ **Use at your own risk.** Always test in a non-production environment first. The authors are not responsible for any damage or data loss.

**Recommendations:**
- Create backups before running scripts
- Test in staging environment
- Have console access available
- Review scripts before execution
- Keep emergency access methods

---

**Last Updated:** 2025-12-26
**Version:** 1.0.1
**Status:** Production Ready ✅
