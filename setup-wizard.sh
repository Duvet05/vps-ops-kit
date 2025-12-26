#!/bin/bash

#############################################
# VPS Operations Toolkit - Setup Wizard
# Ubuntu 22.04-24.04 LTS
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

banner() {
    echo -e "${BLUE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║          VPS Operations Toolkit                      ║
║          Setup Wizard for Ubuntu 22-24               ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root (use sudo)"
    fi
}

# Check Ubuntu version
check_ubuntu_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            error "This script is designed for Ubuntu only"
        fi

        VERSION_NUM=$(echo "$VERSION_ID" | cut -d. -f1)
        if [[ "$VERSION_NUM" -lt 22 ]]; then
            error "This script requires Ubuntu 22.04 or newer"
        fi

        info "Detected: $PRETTY_NAME"
    else
        error "Cannot detect OS version"
    fi
}

# Show main menu
show_menu() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Setup Options"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "  1) 🔒 Configure Firewall (UFW)"
    echo "  2) 📊 Setup Monitoring Stack (Prometheus + Grafana)"
    echo "  3) 💾 Setup Automated Backups"
    echo "  4) 🛡️  Security Hardening (fail2ban, SSH, etc.)"
    echo "  5) 🚀 Complete Setup (All of the above)"
    echo "  6) 🔧 Maintenance Tools"
    echo "  7) ℹ️  System Information"
    echo "  8) ❌ Exit"
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo ""
}

# Run firewall setup
run_firewall_setup() {
    info "Starting firewall setup..."
    bash "$SCRIPT_DIR/scripts/setup-firewall.sh"
}

# Run monitoring setup
run_monitoring_setup() {
    info "Starting monitoring setup..."
    bash "$SCRIPT_DIR/scripts/setup-monitoring.sh"
}

# Run backup setup
run_backup_setup() {
    info "Starting backup setup..."
    bash "$SCRIPT_DIR/scripts/setup-backup.sh"
}

# Run security hardening
run_security_hardening() {
    info "Starting security hardening..."
    bash "$SCRIPT_DIR/scripts/harden-security.sh"
}

# Complete setup
complete_setup() {
    echo ""
    info "Running complete VPS setup..."
    echo ""
    echo "This will configure:"
    echo "  - Firewall (UFW)"
    echo "  - Monitoring Stack"
    echo "  - Automated Backups"
    echo "  - Security Hardening"
    echo ""
    read -p "Continue? (yes/no): " answer

    if [ "$answer" != "yes" ]; then
        info "Setup cancelled"
        return 0
    fi

    run_firewall_setup
    echo ""
    info "Firewall setup completed. Press Enter to continue..."
    read

    run_monitoring_setup
    echo ""
    info "Monitoring setup completed. Press Enter to continue..."
    read

    run_backup_setup
    echo ""
    info "Backup setup completed. Press Enter to continue..."
    read

    run_security_hardening
    echo ""
    success "Complete setup finished!"
}

# Maintenance tools menu
maintenance_menu() {
    while true; do
        echo ""
        echo "═══════════════════════════════════════════════════════"
        echo "  Maintenance Tools"
        echo "═══════════════════════════════════════════════════════"
        echo ""
        echo "  1) Update system packages"
        echo "  2) Clean Docker resources"
        echo "  3) View firewall status"
        echo "  4) View fail2ban status"
        echo "  5) Check disk usage"
        echo "  6) View system logs"
        echo "  7) Back to main menu"
        echo ""
        read -p "Select option (1-7): " choice

        case $choice in
            1)
                info "Updating system packages..."
                apt-get update && apt-get upgrade -y
                success "System updated"
                ;;
            2)
                if command -v docker &> /dev/null; then
                    info "Cleaning Docker resources..."
                    docker system prune -af
                    success "Docker cleaned"
                else
                    warning "Docker not installed"
                fi
                ;;
            3)
                if command -v ufw &> /dev/null; then
                    ufw status verbose
                else
                    warning "UFW not installed"
                fi
                ;;
            4)
                if command -v fail2ban-client &> /dev/null; then
                    fail2ban-client status
                else
                    warning "fail2ban not installed"
                fi
                ;;
            5)
                df -h
                echo ""
                du -sh /* 2>/dev/null | sort -hr | head -20
                ;;
            6)
                journalctl -n 50 --no-pager
                ;;
            7)
                break
                ;;
            *)
                warning "Invalid option"
                ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

# Show system information
show_system_info() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  System Information"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "Hostname: $(hostname)"
    echo "IP Address: $(hostname -I | awk '{print $1}')"
    echo "OS: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo ""
    echo "CPU:"
    lscpu | grep "Model name" | cut -d: -f2 | xargs
    echo "Cores: $(nproc)"
    echo ""
    echo "Memory:"
    free -h | grep "Mem:" | awk '{print "Total: "$2" | Used: "$3" | Free: "$4}'
    echo ""
    echo "Disk:"
    df -h / | tail -1 | awk '{print "Total: "$2" | Used: "$3" | Available: "$4" | Use: "$5}'
    echo ""
    echo "Installed Tools:"
    command -v docker &>/dev/null && echo "  ✓ Docker" || echo "  ✗ Docker"
    command -v docker-compose &>/dev/null && echo "  ✓ Docker Compose" || echo "  ✗ Docker Compose"
    command -v ufw &>/dev/null && echo "  ✓ UFW" || echo "  ✗ UFW"
    command -v fail2ban-client &>/dev/null && echo "  ✓ fail2ban" || echo "  ✗ fail2ban"
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo ""
}

# Main execution
main() {
    banner
    check_root
    check_ubuntu_version

    while true; do
        show_menu
        read -p "Select option (1-8): " choice

        case $choice in
            1)
                run_firewall_setup
                ;;
            2)
                run_monitoring_setup
                ;;
            3)
                run_backup_setup
                ;;
            4)
                run_security_hardening
                ;;
            5)
                complete_setup
                ;;
            6)
                maintenance_menu
                ;;
            7)
                show_system_info
                ;;
            8)
                echo ""
                success "Goodbye!"
                exit 0
                ;;
            *)
                warning "Invalid option. Please try again."
                ;;
        esac

        echo ""
        read -p "Press Enter to return to main menu..."
    done
}

# Run main function
main
