# VPS Operations Toolkit

A comprehensive wizard for Ubuntu 22.04-24.04 VPS setup, security hardening, and maintenance.

## Features

- 🔒 **Firewall Configuration** - UFW setup with common service ports
- 📊 **Monitoring Stack** - Prometheus + Grafana integration
- 💾 **Automated Backups** - Scheduled backups with rotation
- 🛡️ **Security Hardening** - fail2ban, SSH hardening, and best practices
- 🔧 **Maintenance Tools** - System update scripts and health checks

## Compatibility

- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Duvet05/vps-ops-kit.git
cd vps-ops-kit

# Make scripts executable
chmod +x scripts/*.sh

# Run the setup wizard
sudo ./setup-wizard.sh
```

## Components

### 1. Firewall Configuration (`scripts/setup-firewall.sh`)

Configures UFW (Uncomplicated Firewall) with safe defaults:
- SSH (port 22)
- HTTP/HTTPS (ports 80, 443)
- Custom application ports

**Safety Features:**
- Checks for existing firewall configurations
- Prevents duplicate rules
- Always allows SSH before enabling firewall

### 2. Monitoring Stack (`scripts/setup-monitoring.sh`)

Deploys Prometheus and Grafana using Docker:
- Prometheus metrics collection
- Grafana dashboards
- Pre-configured for system monitoring

### 3. Backup System (`scripts/setup-backup.sh`)

Automated backup solution:
- Configurable backup directories
- Automated rotation
- Cron job scheduling
- Compression and timestamping

### 4. Security Hardening (`scripts/harden-security.sh`)

Production-grade security measures:
- fail2ban installation and configuration
- SSH hardening
- Automatic security updates
- System auditing tools

### 5. Maintenance Tools (`scripts/maintenance.sh`)

Common maintenance tasks:
- System updates
- Docker cleanup
- Log rotation
- Health checks

## Usage Examples

### Setup Firewall

```bash
sudo ./scripts/setup-firewall.sh
```

The script will:
1. Check for existing firewall rules
2. Prompt for custom ports
3. Configure UFW safely
4. Enable the firewall

### Deploy Monitoring

```bash
sudo ./scripts/setup-monitoring.sh
```

Access:
- Prometheus: `http://your-server:9090`
- Grafana: `http://your-server:3000` (default: admin/admin)

### Configure Backups

```bash
sudo ./scripts/setup-backup.sh
```

Customize backup paths in the generated configuration.

### Harden Security

```bash
sudo ./scripts/harden-security.sh
```

Implements security best practices automatically.

## Configuration Files

All configuration files are stored in `/etc/vps-ops-kit/`:
- `firewall.conf` - Firewall rules configuration
- `backup.conf` - Backup paths and schedules
- `monitoring.conf` - Monitoring targets

## Safety Notes

⚠️ **Important Safety Warnings:**

1. **Firewall Configuration**: Always ensure SSH (port 22) is allowed before enabling UFW to prevent lockout.
2. **Backup First**: Create system backups before running security hardening scripts.
3. **Test in Staging**: Test all scripts in a non-production environment first.
4. **Review Logs**: Check `/var/log/vps-ops-kit/` for script execution logs.

## Roadmap

- [ ] Support for multiple firewall backends (iptables, nftables)
- [ ] Web-based configuration interface
- [ ] Integration with popular monitoring services
- [ ] Automated SSL certificate management
- [ ] Multi-VPS orchestration

## Contributing

Contributions are welcome! Please read our contributing guidelines.

## License

MIT License - See LICENSE file for details.

## Support

For issues and questions:
- GitHub Issues: https://github.com/Duvet05/vps-ops-kit/issues
- Documentation: https://github.com/Duvet05/vps-ops-kit/wiki

## Credits

Created for Ubuntu VPS administrators who want a reliable, safe, and automated operations toolkit.
