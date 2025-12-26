#!/bin/bash

#############################################
# VPS Monitoring Setup Script
# Prometheus + Grafana deployment
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
MONITORING_DIR="/opt/vps-monitoring"
LOG_DIR="/var/log/vps-ops-kit"
LOG_FILE="$LOG_DIR/monitoring-setup.log"

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

log "Starting monitoring stack setup..."

# Check for Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        warning "Docker not found. Installing Docker..."
        install_docker
    else
        log "Docker is already installed"
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        warning "Docker Compose not found. Installing..."
        install_docker_compose
    else
        log "Docker Compose is already installed"
    fi
}

# Install Docker
install_docker() {
    log "Installing Docker..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release

    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Set up the repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    success "Docker installed successfully"
}

# Install Docker Compose (standalone)
install_docker_compose() {
    log "Installing Docker Compose..."
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    success "Docker Compose installed successfully"
}

# Create monitoring directory structure
create_monitoring_structure() {
    log "Creating monitoring directory structure..."

    if [ -d "$MONITORING_DIR" ]; then
        warning "Monitoring directory already exists at $MONITORING_DIR"
        read -p "Continue and potentially overwrite files? (yes/no): " answer
        if [ "$answer" != "yes" ]; then
            log "User chose not to overwrite. Exiting."
            exit 0
        fi
    fi

    mkdir -p "$MONITORING_DIR"
    mkdir -p "$MONITORING_DIR/prometheus"
    mkdir -p "$MONITORING_DIR/grafana"

    success "Directory structure ready at $MONITORING_DIR"
}

# Create Prometheus configuration
create_prometheus_config() {
    log "Creating Prometheus configuration..."

    if [ -f "$MONITORING_DIR/prometheus/prometheus.yml" ]; then
        log "Prometheus config already exists, skipping creation"
        return 0
    fi

    cat > "$MONITORING_DIR/prometheus/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'vps-monitor'

# Alertmanager configuration (optional)
# alerting:
#   alertmanagers:
#     - static_configs:
#         - targets: ['alertmanager:9093']

scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node Exporter for system metrics
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  # Add your application targets here
  # Example:
  # - job_name: 'my-app'
  #   static_configs:
  #     - targets: ['localhost:8080']
EOF

    success "Prometheus configuration created"
}

# Create Docker Compose file
create_docker_compose() {
    log "Creating Docker Compose configuration..."

    if [ -f "$MONITORING_DIR/docker-compose.yml" ]; then
        log "Docker Compose config already exists, skipping creation"
        return 0
    fi

    cat > "$MONITORING_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    ports:
      - "9091:9090"
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    environment:
      - GF_SECURITY_ADMIN_USER=${ADMIN_USER:-admin}
      - GF_SECURITY_ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin}
      - GF_USERS_ALLOW_SIGN_UP=false
    ports:
      - "3000:3000"
    networks:
      - monitoring
    depends_on:
      - prometheus

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    networks:
      - monitoring

volumes:
  prometheus-data:
  grafana-data:

networks:
  monitoring:
    driver: bridge
EOF

    success "Docker Compose configuration created"
}

# Create Grafana provisioning
create_grafana_provisioning() {
    log "Creating Grafana datasource provisioning..."

    mkdir -p "$MONITORING_DIR/grafana/provisioning/datasources"

    cat > "$MONITORING_DIR/grafana/provisioning/datasources/prometheus.yml" << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

    success "Grafana provisioning configured"
}

# Start monitoring stack
start_monitoring() {
    log "Starting monitoring stack..."

    cd "$MONITORING_DIR"

    # Check if containers are already running
    if docker ps | grep -q "prometheus"; then
        log "Prometheus container already running"
        read -p "Restart monitoring stack? (yes/no): " answer
        if [ "$answer" != "yes" ]; then
            log "Skipping container restart"
            return 0
        fi
    fi

    # Check if using docker-compose or docker compose
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi

    success "Monitoring stack started successfully"
}

# Show status and access information
show_status() {
    echo ""
    echo "=========================================="
    echo "Monitoring Stack Information"
    echo "=========================================="
    echo ""
    echo "Services:"
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$MONITORING_DIR/docker-compose.yml" ps
    else
        docker compose -f "$MONITORING_DIR/docker-compose.yml" ps
    fi
    echo ""
    echo "Access URLs:"
    echo "  Prometheus: http://$(hostname -I | awk '{print $1}'):9091"
    echo "  Grafana:    http://$(hostname -I | awk '{print $1}'):3000"
    echo ""
    echo "Grafana Default Credentials:"
    echo "  Username: admin"
    echo "  Password: admin"
    echo ""
    echo "⚠️  SECURITY WARNING ⚠️"
    echo "  Change the default password IMMEDIATELY!"
    echo "  The monitoring ports are exposed - configure firewall if needed"
    echo ""
    echo "Node Exporter: http://$(hostname -I | awk '{print $1}'):9100/metrics"
    echo ""
    echo "=========================================="
    echo ""
}

# Create helper scripts
create_helper_scripts() {
    log "Creating helper scripts..."

    # Start script
    cat > "$MONITORING_DIR/start.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
if command -v docker-compose &> /dev/null; then
    docker-compose up -d
else
    docker compose up -d
fi
echo "Monitoring stack started"
EOF

    # Stop script
    cat > "$MONITORING_DIR/stop.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
if command -v docker-compose &> /dev/null; then
    docker-compose down
else
    docker compose down
fi
echo "Monitoring stack stopped"
EOF

    # Logs script
    cat > "$MONITORING_DIR/logs.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
if command -v docker-compose &> /dev/null; then
    docker-compose logs -f
else
    docker compose logs -f
fi
EOF

    chmod +x "$MONITORING_DIR"/*.sh

    success "Helper scripts created in $MONITORING_DIR"
}

# Configure firewall
configure_firewall() {
    echo ""
    read -p "Do you want to configure firewall rules for monitoring ports? (yes/no): " answer

    if [ "$answer" == "yes" ]; then
        if command -v ufw &> /dev/null; then
            log "Configuring UFW rules..."

            # Check if rules already exist
            if ! ufw status | grep -q "9091/tcp"; then
                ufw allow 9091/tcp comment 'Prometheus'
                log "Added Prometheus port (9091)"
            else
                log "Prometheus port (9091) already allowed"
            fi

            if ! ufw status | grep -q "3000/tcp"; then
                ufw allow 3000/tcp comment 'Grafana'
                log "Added Grafana port (3000)"
            else
                log "Grafana port (3000) already allowed"
            fi

            success "Firewall rules configured for monitoring"
        else
            warning "UFW not found. Please configure firewall manually for ports 3000 and 9091"
        fi
    fi
}

# Main execution
main() {
    log "=== VPS Monitoring Setup Started ==="

    check_docker
    create_monitoring_structure
    create_prometheus_config
    create_docker_compose
    create_grafana_provisioning
    create_helper_scripts
    start_monitoring
    configure_firewall
    show_status

    log "=== VPS Monitoring Setup Completed ==="

    echo ""
    success "Monitoring stack setup complete!"
    echo ""
    echo "Files location: $MONITORING_DIR"
    echo "Logs: $LOG_FILE"
    echo ""
    echo "Useful commands:"
    echo "  cd $MONITORING_DIR && ./logs.sh    - View logs"
    echo "  cd $MONITORING_DIR && ./stop.sh    - Stop monitoring"
    echo "  cd $MONITORING_DIR && ./start.sh   - Start monitoring"
    echo ""
    echo "⚠️  CRITICAL SECURITY STEPS ⚠️"
    echo ""
    echo "1. IMMEDIATELY change Grafana password:"
    echo "   - Login at http://YOUR_IP:3000"
    echo "   - Username: admin, Password: admin"
    echo "   - You will be prompted to change password"
    echo ""
    echo "2. Configure firewall to restrict access:"
    echo "   - Only allow trusted IPs to ports 3000 and 9091"
    echo "   - Consider using a reverse proxy with HTTPS"
    echo ""
    echo "Note: Prometheus uses port 9091 (not 9090) to avoid"
    echo "      conflict with LiveKit Ingress service"
    echo ""
    echo "Next steps:"
    echo "  1. Import dashboards (Dashboard ID 1860 for Node Exporter)"
    echo "  2. Configure alerting rules in Prometheus"
    echo "  3. Set up SSL/TLS (recommended for production)"
    echo ""
}

# Run main function
main
