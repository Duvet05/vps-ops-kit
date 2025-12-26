#!/bin/bash

#############################################
# VPS Security Hardening Script
# Production-grade security measures
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
LOG_DIR="/var/log/vps-ops-kit"
LOG_FILE="$LOG_DIR/security-hardening.log"

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root (use sudo)"
fi

log "Starting security hardening..."

# Backup SSH config before modifying
backup_ssh_config() {
    if [ -f /etc/ssh/sshd_config ]; then
        log "Backing up SSH configuration..."
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
        success "SSH config backed up"
    fi
}

# Install fail2ban
install_fail2ban() {
    log "Installing fail2ban..."

    if command -v fail2ban-client &> /dev/null; then
        log "fail2ban is already installed"
    else
        apt-get update
        apt-get install -y fail2ban
        success "fail2ban installed"
    fi

    # Create local configuration
    log "Configuring fail2ban..."

    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban hosts for 1 hour:
bantime = 3600

# Find time window
findtime = 600

# Max retry attempts
maxretry = 3

# Email notifications (configure if needed)
# destemail = your@email.com
# sendername = Fail2Ban
# action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 3
bantime = 3600
findtime = 600

[sshd-ddos]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 2
bantime = 7200
findtime = 300
EOF

    # Restart fail2ban
    systemctl enable fail2ban
    systemctl restart fail2ban

    success "fail2ban configured and started"
}

# Harden SSH configuration
harden_ssh() {
    log "Hardening SSH configuration..."

    echo ""
    echo "SSH Hardening Options:"
    echo "  1) Full hardening (recommended)"
    echo "  2) Basic hardening"
    echo "  3) Skip SSH hardening"
    echo ""
    read -p "Select option (1-3): " ssh_option

    if [ "$ssh_option" = "3" ]; then
        log "Skipping SSH hardening"
        return 0
    fi

    backup_ssh_config

    # Basic hardening
    log "Applying basic SSH hardening..."

    # Disable root login
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

    # Disable password authentication (use keys only)
    read -p "Disable password authentication? (requires SSH key setup) (yes/no): " disable_pwd
    if [ "$disable_pwd" = "yes" ]; then
        sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        warning "Password authentication disabled. Ensure you have SSH keys configured!"
    fi

    # Disable empty passwords
    sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config

    # Set maximum authentication attempts
    sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config

    if [ "$ssh_option" = "1" ]; then
        # Full hardening
        log "Applying advanced SSH hardening..."

        # Disable X11 forwarding
        sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config

        # Set login grace time
        sed -i 's/^#\?LoginGraceTime.*/LoginGraceTime 30/' /etc/ssh/sshd_config

        # Set max sessions
        sed -i 's/^#\?MaxSessions.*/MaxSessions 2/' /etc/ssh/sshd_config

        # Use only strong ciphers
        if ! grep -q "^Ciphers" /etc/ssh/sshd_config; then
            echo "" >> /etc/ssh/sshd_config
            echo "# Strong ciphers only" >> /etc/ssh/sshd_config
            echo "Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr" >> /etc/ssh/sshd_config
        fi

        # Use only strong MACs
        if ! grep -q "^MACs" /etc/ssh/sshd_config; then
            echo "MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256" >> /etc/ssh/sshd_config
        fi

        # Use only strong key exchange algorithms
        if ! grep -q "^KexAlgorithms" /etc/ssh/sshd_config; then
            echo "KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512" >> /etc/ssh/sshd_config
        fi
    fi

    # Test SSH config
    if sshd -t; then
        success "SSH configuration is valid"
        systemctl restart sshd
        success "SSH service restarted"
    else
        error "SSH configuration test failed! Restoring backup..."
        cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config
    fi
}

# Setup automatic security updates
setup_auto_updates() {
    log "Setting up automatic security updates..."

    apt-get install -y unattended-upgrades apt-listchanges

    # Configure unattended upgrades
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF

    # Enable automatic updates
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

    success "Automatic security updates configured"
}

# Install and configure auditd
setup_auditd() {
    log "Installing auditd (system auditing)..."

    read -p "Install auditd for system auditing? (yes/no): " install_audit

    if [ "$install_audit" = "yes" ]; then
        apt-get install -y auditd audispd-plugins

        # Add basic audit rules
        cat >> /etc/audit/rules.d/audit.rules << 'EOF'

## Monitor user/group changes
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity

## Monitor sudo usage
-w /etc/sudoers -p wa -k actions
-w /etc/sudoers.d/ -p wa -k actions

## Monitor SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd

## Monitor login/logout
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock/ -p wa -k logins

## Monitor network configuration
-w /etc/network/ -p wa -k network
EOF

        # Restart auditd
        systemctl enable auditd
        systemctl restart auditd

        success "auditd installed and configured"
    else
        log "Skipping auditd installation"
    fi
}

# Disable unnecessary services
disable_services() {
    log "Checking for unnecessary services..."

    # List of potentially unnecessary services
    SERVICES_TO_CHECK=(
        "avahi-daemon"
        "cups"
        "bluetooth"
    )

    for service in "${SERVICES_TO_CHECK[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log "Found active service: $service"
            read -p "Disable $service? (yes/no): " answer
            if [ "$answer" = "yes" ]; then
                systemctl stop "$service"
                systemctl disable "$service"
                log "Disabled: $service"
            fi
        fi
    done
}

# Configure system limits
configure_limits() {
    log "Configuring system limits..."

    # Increase file descriptor limits
    if ! grep -q "* soft nofile" /etc/security/limits.conf; then
        cat >> /etc/security/limits.conf << 'EOF'

# Increased file descriptor limits
* soft nofile 65536
* hard nofile 65536
EOF
        success "File descriptor limits increased"
    fi
}

# Install security tools
install_security_tools() {
    log "Installing additional security tools..."

    read -p "Install security analysis tools? (rkhunter, lynis) (yes/no): " install_tools

    if [ "$install_tools" = "yes" ]; then
        apt-get install -y rkhunter lynis

        # Update rkhunter database
        rkhunter --update

        success "Security tools installed"
        echo ""
        echo "Run security scans with:"
        echo "  sudo rkhunter --check"
        echo "  sudo lynis audit system"
        echo ""
    fi
}

# Generate security report
generate_report() {
    REPORT_FILE="$LOG_DIR/security-report-$(date +%Y%m%d).txt"

    log "Generating security report..."

    cat > "$REPORT_FILE" << EOF
VPS Security Hardening Report
Generated: $(date)
Hostname: $(hostname)

=== System Information ===
$(uname -a)
$(lsb_release -a 2>/dev/null)

=== fail2ban Status ===
$(fail2ban-client status 2>/dev/null || echo "fail2ban not running")

=== SSH Configuration ===
Port: $(grep "^Port" /etc/ssh/sshd_config || echo "22 (default)")
PermitRootLogin: $(grep "^PermitRootLogin" /etc/ssh/sshd_config)
PasswordAuthentication: $(grep "^PasswordAuthentication" /etc/ssh/sshd_config)

=== Firewall Status ===
$(ufw status verbose 2>/dev/null || echo "UFW not configured")

=== Open Ports ===
$(ss -tlnp)

=== Recent Failed Login Attempts ===
$(grep "Failed password" /var/log/auth.log 2>/dev/null | tail -20 || echo "No recent failed logins")

=== Installed Security Tools ===
fail2ban: $(command -v fail2ban-client &>/dev/null && echo "Installed" || echo "Not installed")
rkhunter: $(command -v rkhunter &>/dev/null && echo "Installed" || echo "Not installed")
lynis: $(command -v lynis &>/dev/null && echo "Installed" || echo "Not installed")
auditd: $(systemctl is-active auditd 2>/dev/null || echo "Not running")

=== Recommendations ===
1. Review firewall rules regularly
2. Monitor fail2ban logs: /var/log/fail2ban.log
3. Run security scans periodically
4. Keep system updated
5. Review SSH logs: /var/log/auth.log
EOF

    success "Security report generated: $REPORT_FILE"
}

# Show summary
show_summary() {
    echo ""
    echo "=========================================="
    echo "Security Hardening Summary"
    echo "=========================================="
    echo ""
    echo "Completed tasks:"
    echo "  ✓ fail2ban installed and configured"
    echo "  ✓ SSH hardened"
    echo "  ✓ Automatic security updates enabled"
    echo "  ✓ System auditing configured"
    echo ""
    echo "Important files:"
    echo "  SSH config: /etc/ssh/sshd_config"
    echo "  SSH backup: /etc/ssh/sshd_config.backup.*"
    echo "  fail2ban config: /etc/fail2ban/jail.local"
    echo "  Security report: $LOG_DIR/security-report-*.txt"
    echo ""
    echo "=========================================="
    echo ""
}

# Main execution
main() {
    log "=== VPS Security Hardening Started ==="

    echo ""
    echo "⚠️  WARNING ⚠️"
    echo ""
    echo "This script will modify system security settings."
    echo "Ensure you have:"
    echo "  1. Console access to this server"
    echo "  2. SSH keys configured (if disabling password auth)"
    echo "  3. Current backup of important data"
    echo ""
    read -p "Continue with security hardening? (yes/no): " proceed

    if [ "$proceed" != "yes" ]; then
        log "User chose not to proceed. Exiting."
        exit 0
    fi

    install_fail2ban
    harden_ssh
    setup_auto_updates
    setup_auditd
    disable_services
    configure_limits
    install_security_tools
    generate_report
    show_summary

    log "=== VPS Security Hardening Completed ==="

    echo ""
    success "Security hardening complete!"
    echo ""
    echo "⚠️  IMPORTANT: Test SSH connection in a NEW terminal before closing this one!"
    echo ""
    echo "Next steps:"
    echo "  1. Review security report: cat $LOG_DIR/security-report-*.txt"
    echo "  2. Test SSH connection"
    echo "  3. Configure fail2ban notifications"
    echo "  4. Schedule regular security scans"
    echo ""
    echo "Logs: $LOG_FILE"
    echo ""
}

# Run main function
main
