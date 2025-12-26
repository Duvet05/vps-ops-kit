#!/bin/bash

#############################################
# VPS Backup Setup Script
# Automated backup with rotation
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
BACKUP_SCRIPT_DIR="/opt/vps-backup"
LOG_DIR="/var/log/vps-ops-kit"
LOG_FILE="$LOG_DIR/backup-setup.log"

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

log "Starting backup system setup..."

# Create backup directory structure
create_backup_structure() {
    log "Creating backup directory structure..."

    if [ -d "$BACKUP_SCRIPT_DIR" ]; then
        warning "Backup directory already exists at $BACKUP_SCRIPT_DIR"
        read -p "Continue and potentially overwrite files? (yes/no): " answer
        if [ "$answer" != "yes" ]; then
            log "User chose not to overwrite. Exiting."
            exit 0
        fi
    fi

    mkdir -p "$BACKUP_SCRIPT_DIR"
    mkdir -p "$BACKUP_SCRIPT_DIR/config"

    success "Directory structure ready at $BACKUP_SCRIPT_DIR"
}

# Create backup configuration
create_backup_config() {
    log "Creating backup configuration..."

    if [ -f "$BACKUP_SCRIPT_DIR/config/backup.conf" ]; then
        log "Backup configuration already exists, skipping creation"
        return 0
    fi

    cat > "$BACKUP_SCRIPT_DIR/config/backup.conf" << 'EOF'
# VPS Backup Configuration
# Edit this file to customize your backup settings
# WARNING: This file may contain sensitive credentials - keep it secure!

# Backup destination
BACKUP_DIR="/var/backups/vps"

# Retention policy (days)
RETENTION_DAYS=7

# Directories to backup (space-separated)
BACKUP_PATHS=(
    "/etc"
    "/home"
    "/root"
    "/var/www"
    "/opt"
)

# Exclude patterns (one per line in backup script)
EXCLUDE_PATTERNS=(
    "*.log"
    "*.tmp"
    "cache/*"
    "tmp/*"
)

# Docker containers to backup (if any)
BACKUP_DOCKER=true
DOCKER_VOLUMES=(
    # Add volume names here, e.g.:
    # "my-app-data"
    # "postgres-data"
)

# Database backups
BACKUP_MYSQL=false
MYSQL_USER="backup_user"
MYSQL_PASSWORD=""
MYSQL_DATABASES=()

BACKUP_POSTGRES=false
POSTGRES_USER="postgres"
POSTGRES_DATABASES=()

# Compression
USE_COMPRESSION=true
COMPRESSION_LEVEL=6

# Notifications (future feature)
ENABLE_NOTIFICATIONS=false
NOTIFICATION_EMAIL=""
EOF

    # Secure the configuration file (contains sensitive data)
    chmod 600 "$BACKUP_SCRIPT_DIR/config/backup.conf"
    chown root:root "$BACKUP_SCRIPT_DIR/config/backup.conf"

    success "Backup configuration created at $BACKUP_SCRIPT_DIR/config/backup.conf"
    warning "Configuration file secured with 600 permissions (contains sensitive data)"
}

# Create main backup script
create_backup_script() {
    log "Creating backup script..."

    if [ -f "$BACKUP_SCRIPT_DIR/backup.sh" ]; then
        log "Backup script already exists, skipping creation"
        return 0
    fi

    cat > "$BACKUP_SCRIPT_DIR/backup.sh" << 'EOFSCRIPT'
#!/bin/bash

#############################################
# Automated Backup Script
#############################################

set -e

# Load configuration
CONFIG_FILE="/opt/vps-backup/config/backup.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# Variables
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_LOG="/var/log/vps-ops-kit/backup-$(date +%Y%m%d).log"
mkdir -p "$BACKUP_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$BACKUP_LOG"
}

error() {
    echo "[ERROR] $1" | tee -a "$BACKUP_LOG"
    exit 1
}

# Start backup
log "=== Backup Started ==="

# Create timestamp directory
BACKUP_TARGET="$BACKUP_DIR/$TIMESTAMP"
mkdir -p "$BACKUP_TARGET"

# Backup filesystem
if [ ${#BACKUP_PATHS[@]} -gt 0 ]; then
    log "Backing up filesystem directories..."

    for path in "${BACKUP_PATHS[@]}"; do
        if [ -d "$path" ]; then
            log "Backing up: $path"
            backup_name=$(echo "$path" | tr '/' '_')

            if [ "$USE_COMPRESSION" = true ]; then
                tar -czf "$BACKUP_TARGET/filesystem${backup_name}.tar.gz" \
                    --exclude='*.log' \
                    --exclude='*.tmp' \
                    --exclude='cache/*' \
                    --exclude='tmp/*' \
                    "$path" 2>> "$BACKUP_LOG" || log "Warning: Some files in $path were not backed up"
            else
                tar -cf "$BACKUP_TARGET/filesystem${backup_name}.tar" \
                    --exclude='*.log' \
                    --exclude='*.tmp' \
                    --exclude='cache/*' \
                    --exclude='tmp/*' \
                    "$path" 2>> "$BACKUP_LOG" || log "Warning: Some files in $path were not backed up"
            fi

            log "Completed: $path"
        else
            log "Warning: Directory not found: $path"
        fi
    done
fi

# Backup Docker volumes
if [ "$BACKUP_DOCKER" = true ] && command -v docker &> /dev/null; then
    if [ ${#DOCKER_VOLUMES[@]} -gt 0 ]; then
        log "Backing up Docker volumes..."

        for volume in "${DOCKER_VOLUMES[@]}"; do
            if docker volume inspect "$volume" &> /dev/null; then
                log "Backing up Docker volume: $volume"
                docker run --rm \
                    -v "$volume":/volume \
                    -v "$BACKUP_TARGET":/backup \
                    alpine \
                    tar czf "/backup/docker-volume-${volume}.tar.gz" -C /volume . \
                    2>> "$BACKUP_LOG"

                log "Completed: $volume"
            else
                log "Warning: Docker volume not found: $volume"
            fi
        done
    fi
fi

# Backup MySQL databases
if [ "$BACKUP_MYSQL" = true ] && command -v mysqldump &> /dev/null; then
    if [ ${#MYSQL_DATABASES[@]} -gt 0 ]; then
        log "Backing up MySQL databases..."

        for db in "${MYSQL_DATABASES[@]}"; do
            log "Backing up MySQL database: $db"
            mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$db" \
                | gzip > "$BACKUP_TARGET/mysql-${db}.sql.gz" \
                2>> "$BACKUP_LOG" || log "Warning: Failed to backup $db"

            log "Completed: $db"
        done
    fi
fi

# Backup PostgreSQL databases
if [ "$BACKUP_POSTGRES" = true ] && command -v pg_dump &> /dev/null; then
    if [ ${#POSTGRES_DATABASES[@]} -gt 0 ]; then
        log "Backing up PostgreSQL databases..."

        for db in "${POSTGRES_DATABASES[@]}"; do
            log "Backing up PostgreSQL database: $db"
            sudo -u "$POSTGRES_USER" pg_dump "$db" \
                | gzip > "$BACKUP_TARGET/postgres-${db}.sql.gz" \
                2>> "$BACKUP_LOG" || log "Warning: Failed to backup $db"

            log "Completed: $db"
        done
    fi
fi

# Create backup manifest
log "Creating backup manifest..."
cat > "$BACKUP_TARGET/manifest.txt" << EOF
Backup created: $(date)
Hostname: $(hostname)
Files included:
$(find "$BACKUP_TARGET" -type f -exec ls -lh {} \;)

Total backup size: $(du -sh "$BACKUP_TARGET" | cut -f1)
EOF

# Cleanup old backups
log "Cleaning up old backups (retention: $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>> "$BACKUP_LOG"

# Calculate backup size
BACKUP_SIZE=$(du -sh "$BACKUP_TARGET" | cut -f1)
log "Backup completed. Size: $BACKUP_SIZE"
log "=== Backup Finished ==="

# Summary
echo ""
echo "Backup Summary:"
echo "  Location: $BACKUP_TARGET"
echo "  Size: $BACKUP_SIZE"
echo "  Log: $BACKUP_LOG"
echo ""
EOFSCRIPT

    chmod 700 "$BACKUP_SCRIPT_DIR/backup.sh"
    chown root:root "$BACKUP_SCRIPT_DIR/backup.sh"

    success "Backup script created at $BACKUP_SCRIPT_DIR/backup.sh"
}

# Create restore helper script
create_restore_script() {
    log "Creating restore helper script..."

    if [ -f "$BACKUP_SCRIPT_DIR/restore.sh" ]; then
        log "Restore script already exists, skipping creation"
        return 0
    fi

    cat > "$BACKUP_SCRIPT_DIR/restore.sh" << 'EOFSCRIPT'
#!/bin/bash

#############################################
# Backup Restore Helper Script
#############################################

BACKUP_DIR="/var/backups/vps"

echo "Available backups:"
echo ""
ls -1 "$BACKUP_DIR" | nl
echo ""

read -p "Select backup number to restore from: " backup_num
backup_name=$(ls -1 "$BACKUP_DIR" | sed -n "${backup_num}p")

if [ -z "$backup_name" ]; then
    echo "Invalid selection"
    exit 1
fi

RESTORE_FROM="$BACKUP_DIR/$backup_name"

echo ""
echo "Backup: $RESTORE_FROM"
echo ""
echo "Contents:"
ls -lh "$RESTORE_FROM"
echo ""

read -p "Enter the file to restore (or 'all' for everything): " file_choice

if [ "$file_choice" = "all" ]; then
    echo "This will extract all files. Be careful!"
    read -p "Continue? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        echo "Restoring all files..."
        for file in "$RESTORE_FROM"/*.tar.gz; do
            echo "Extracting: $file"
            tar -xzf "$file" -C /
        done
        echo "Restore completed"
    fi
else
    if [ -f "$RESTORE_FROM/$file_choice" ]; then
        echo "Extracting: $file_choice"
        tar -xzf "$RESTORE_FROM/$file_choice" -C /
        echo "Restore completed"
    else
        echo "File not found: $file_choice"
        exit 1
    fi
fi
EOFSCRIPT

    chmod 700 "$BACKUP_SCRIPT_DIR/restore.sh"
    chown root:root "$BACKUP_SCRIPT_DIR/restore.sh"

    success "Restore script created at $BACKUP_SCRIPT_DIR/restore.sh"
}

# Setup cron job
setup_cron() {
    log "Setting up automated backups..."

    echo ""
    echo "Backup scheduling options:"
    echo "  1) Daily at 2:00 AM"
    echo "  2) Daily at custom time"
    echo "  3) Weekly (Sunday at 2:00 AM)"
    echo "  4) Skip (manual backups only)"
    echo ""
    read -p "Select option (1-4): " schedule_option

    case $schedule_option in
        1)
            cron_schedule="0 2 * * *"
            description="Daily at 2:00 AM"
            ;;
        2)
            read -p "Enter hour (0-23): " hour
            read -p "Enter minute (0-59): " minute
            cron_schedule="$minute $hour * * *"
            description="Daily at $hour:$minute"
            ;;
        3)
            cron_schedule="0 2 * * 0"
            description="Weekly on Sunday at 2:00 AM"
            ;;
        4)
            log "Skipping cron setup"
            return 0
            ;;
        *)
            warning "Invalid option. Skipping cron setup"
            return 0
            ;;
    esac

    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "$BACKUP_SCRIPT_DIR/backup.sh"; then
        log "Cron job for backup already exists"
        read -p "Update existing cron schedule? (yes/no): " update_cron
        if [ "$update_cron" != "yes" ]; then
            log "Keeping existing cron job"
            return 0
        fi
        # Remove old entry
        crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT_DIR/backup.sh" | crontab -
    fi

    # Add cron job
    (crontab -l 2>/dev/null; echo "$cron_schedule $BACKUP_SCRIPT_DIR/backup.sh") | crontab -

    success "Cron job added: $description"
    log "Backup scheduled: $cron_schedule"
}

# Test backup
test_backup() {
    echo ""
    read -p "Do you want to run a test backup now? (yes/no): " answer

    if [ "$answer" = "yes" ]; then
        log "Running test backup..."
        "$BACKUP_SCRIPT_DIR/backup.sh"
    fi
}

# Show summary
show_summary() {
    echo ""
    echo "=========================================="
    echo "Backup System Configuration"
    echo "=========================================="
    echo ""
    echo "Files location: $BACKUP_SCRIPT_DIR"
    echo "Configuration: $BACKUP_SCRIPT_DIR/config/backup.conf"
    echo "Backup script: $BACKUP_SCRIPT_DIR/backup.sh"
    echo "Restore script: $BACKUP_SCRIPT_DIR/restore.sh"
    echo ""
    echo "Scheduled backups:"
    crontab -l | grep "$BACKUP_SCRIPT_DIR/backup.sh" || echo "  No automated backups scheduled"
    echo ""
    echo "=========================================="
    echo ""
}

# Main execution
main() {
    log "=== VPS Backup Setup Started ==="

    create_backup_structure
    create_backup_config
    create_backup_script
    create_restore_script
    setup_cron
    test_backup
    show_summary

    log "=== VPS Backup Setup Completed ==="

    echo ""
    success "Backup system setup complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Edit configuration: $BACKUP_SCRIPT_DIR/config/backup.conf"
    echo "  2. Add paths, databases, and Docker volumes to backup"
    echo "  3. Run manual backup: $BACKUP_SCRIPT_DIR/backup.sh"
    echo "  4. Test restore: $BACKUP_SCRIPT_DIR/restore.sh"
    echo ""
    echo "Logs: $LOG_FILE"
    echo ""
}

# Run main function
main
