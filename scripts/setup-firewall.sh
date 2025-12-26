#!/bin/bash

#############################################
# VPS Firewall Setup Script
# Safe UFW configuration for Ubuntu 22-24
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log file
LOG_DIR="/var/log/vps-ops-kit"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/firewall-setup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root (use sudo)"
fi

log "Starting firewall setup..."

# Check for existing firewall configurations
check_existing_firewalls() {
    log "Checking for existing firewall configurations..."

    # Check if UFW is already enabled
    if ufw status | grep -q "Status: active"; then
        warning "UFW is already active!"
        echo ""
        echo "Current UFW rules:"
        ufw status numbered
        echo ""
        read -p "Do you want to continue and modify existing rules? (yes/no): " answer
        if [ "$answer" != "yes" ]; then
            log "User chose not to modify existing UFW rules. Exiting."
            exit 0
        fi
    fi

    # Check for iptables rules
    if iptables -L -n | grep -qv "^Chain\|^target"; then
        warning "Existing iptables rules detected!"
        echo ""
        echo "Current iptables rules:"
        iptables -L -n
        echo ""
        read -p "UFW will override these rules. Continue? (yes/no): " answer
        if [ "$answer" != "yes" ]; then
            log "User chose not to proceed with existing iptables rules. Exiting."
            exit 0
        fi
    fi

    # Check for firewalld
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        warning "firewalld is running!"
        echo ""
        read -p "Do you want to stop firewalld and use UFW instead? (yes/no): " answer
        if [ "$answer" == "yes" ]; then
            systemctl stop firewalld
            systemctl disable firewalld
            success "firewalld stopped and disabled"
        else
            error "Cannot proceed with firewalld running. Please disable it manually."
        fi
    fi
}

# Install UFW if not present
install_ufw() {
    if ! command -v ufw &> /dev/null; then
        log "UFW not found. Installing..."
        apt-get update
        apt-get install -y ufw
        success "UFW installed successfully"
    else
        log "UFW is already installed"
    fi
}

# Configure basic rules
configure_basic_rules() {
    log "Configuring basic firewall rules..."

    # Reset UFW to defaults (asks for confirmation)
    read -p "Reset UFW to default settings? (recommended for first-time setup) (yes/no): " answer
    if [ "$answer" == "yes" ]; then
        ufw --force reset
        success "UFW reset to defaults"
    fi

    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    log "Default policies set: deny incoming, allow outgoing"

    # CRITICAL: Always allow SSH first to prevent lockout
    log "Allowing SSH (port 22) - CRITICAL for remote access"
    ufw allow 22/tcp comment 'SSH'
    success "SSH access allowed on port 22"

    # Allow HTTP and HTTPS
    log "Allowing HTTP and HTTPS"
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    success "HTTP (80) and HTTPS (443) allowed"
}

# Configure application-specific ports
configure_app_ports() {
    log "Configuring application-specific ports..."

    echo ""
    echo "Would you like to configure additional ports for specific applications?"
    echo ""
    echo "Common presets available:"
    echo "  1) LiveKit WebRTC Server"
    echo "  2) Custom ports"
    echo "  3) Skip (only basic HTTP/HTTPS/SSH)"
    echo ""
    read -p "Select option (1-3): " preset

    case $preset in
        1)
            log "Configuring LiveKit WebRTC Server ports..."
            ufw allow 7881/tcp comment 'LiveKit WebRTC over TCP'
            ufw allow 3478/udp comment 'LiveKit TURN/UDP'
            ufw allow 50000:60000/udp comment 'LiveKit WebRTC UDP Range'
            ufw allow 1935/tcp comment 'LiveKit RTMP Ingress'
            ufw allow 7885/udp comment 'LiveKit WHIP Ingress WebRTC'
            success "LiveKit ports configured"
            ;;
        2)
            configure_custom_ports
            ;;
        3)
            log "Skipping additional port configuration"
            ;;
        *)
            warning "Invalid option. Skipping additional port configuration"
            ;;
    esac
}

# Configure custom ports
configure_custom_ports() {
    echo ""
    echo "Enter custom ports (format: PORT/PROTOCOL COMMENT)"
    echo "Examples:"
    echo "  8080/tcp Web Application"
    echo "  3000/tcp Grafana"
    echo "  9090/tcp Prometheus"
    echo ""
    echo "Enter one port per line. Press CTRL+D when done."
    echo ""

    while IFS= read -r line; do
        if [ -n "$line" ]; then
            # Parse the line
            port_proto=$(echo "$line" | awk '{print $1}')
            comment=$(echo "$line" | cut -d' ' -f2-)

            if [ -n "$port_proto" ]; then
                ufw allow "$port_proto" comment "$comment"
                log "Added rule: $port_proto ($comment)"
            fi
        fi
    done

    success "Custom ports configured"
}

# Show final configuration
show_configuration() {
    echo ""
    echo "=========================================="
    echo "Final Firewall Configuration"
    echo "=========================================="
    ufw status numbered
    echo "=========================================="
    echo ""
}

# Enable UFW
enable_ufw() {
    log "Enabling UFW..."

    echo ""
    echo "⚠️  IMPORTANT SAFETY CHECK ⚠️"
    echo ""
    echo "Before enabling the firewall, verify that:"
    echo "  1. SSH (port 22) is allowed in the rules above"
    echo "  2. You have console access to this server (in case of lockout)"
    echo "  3. All required application ports are configured"
    echo ""
    read -p "Are you sure you want to enable the firewall? (yes/no): " answer

    if [ "$answer" == "yes" ]; then
        ufw --force enable
        success "UFW enabled successfully!"

        echo ""
        echo "Firewall is now active. Current status:"
        ufw status verbose
    else
        warning "UFW not enabled. Run 'sudo ufw enable' when ready."
        log "User chose not to enable UFW"
    fi
}

# Save configuration
save_configuration() {
    CONFIG_DIR="/etc/vps-ops-kit"
    mkdir -p "$CONFIG_DIR"

    ufw status numbered > "$CONFIG_DIR/firewall.conf"
    log "Configuration saved to $CONFIG_DIR/firewall.conf"
}

# Main execution
main() {
    log "=== VPS Firewall Setup Started ==="

    check_existing_firewalls
    install_ufw
    configure_basic_rules
    configure_app_ports
    show_configuration
    enable_ufw
    save_configuration

    log "=== VPS Firewall Setup Completed ==="

    echo ""
    success "Firewall setup complete!"
    echo ""
    echo "Next steps:"
    echo "  - Test your SSH connection in a NEW terminal (don't close this one!)"
    echo "  - Verify application connectivity"
    echo "  - Check logs at: $LOG_FILE"
    echo ""
    echo "Useful commands:"
    echo "  sudo ufw status          - View firewall status"
    echo "  sudo ufw allow PORT      - Allow a port"
    echo "  sudo ufw delete NUM      - Delete a rule by number"
    echo "  sudo ufw disable         - Disable firewall"
    echo ""
}

# Run main function
main
