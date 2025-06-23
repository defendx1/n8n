#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    n8n Docker Installer                     ║${NC}"
echo -e "${BLUE}║                Made by Defendx1.com                         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use sudo."
    fi
}

get_domain_info() {
    echo -e "${BLUE}Enter your domain details:${NC}"
    read -p "Domain (e.g., n8n.example.com): " DOMAIN
    read -p "Email for SSL certificate: " EMAIL
    
    if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
        error "Domain and email are required."
    fi
    
    if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        error "Invalid domain format. Please enter a valid domain like n8n.example.com"
    fi
    
    if [[ ! "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        error "Invalid email format. Please enter a valid email address."
    fi
    
    N8N_PORT="5678"
    DOCKER_NETWORK="defendx1_network"
    N8N_CONTAINER_NAME="n8n_${DOMAIN//\./_}"
    N8N_DATA_DIR="/opt/n8n_${DOMAIN//\./_}"
    NGINX_SITES_DIR="/etc/nginx/sites-available"
    NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
    
    log "Domain: $DOMAIN"
    log "Email: $EMAIL"
    log "Container: $N8N_CONTAINER_NAME"
    log "Data Directory: $N8N_DATA_DIR"
}

update_system() {
    log "Updating system packages..."
    apt update && apt upgrade -y
}

install_docker() {
    if ! command -v docker &> /dev/null; then
        log "Installing Docker..."
        apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io
        systemctl enable docker
        systemctl start docker
        log "Docker installed and started ✓"
    else
        log "Docker already installed ✓"
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log "Installing Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        log "Docker Compose installed ✓"
    else
        log "Docker Compose already installed ✓"
    fi
}

install_nginx() {
    if ! command -v nginx &> /dev/null; then
        log "Installing Nginx..."
        apt install -y nginx
        systemctl enable nginx
        systemctl start nginx
        log "Nginx installed and started ✓"
    else
        log "Nginx already installed ✓"
    fi
}

install_certbot() {
    if ! command -v certbot &> /dev/null; then
        log "Installing Certbot..."
        apt install -y certbot python3-certbot-nginx
        log "Certbot installed ✓"
    else
        log "Certbot already installed ✓"
    fi
}

check_port_conflicts() {
    log "Checking for port conflicts on $N8N_PORT..."
    
    AVAILABLE_PORT=$N8N_PORT
    while true; do
        PORT_IN_USE=false
        
        if command -v netstat &> /dev/null; then
            if netstat -tuln | grep -q ":${AVAILABLE_PORT} "; then
                PORT_IN_USE=true
            fi
        elif command -v ss &> /dev/null; then
            if ss -tuln | grep -q ":${AVAILABLE_PORT} "; then
                PORT_IN_USE=true
            fi
        fi
        
        if docker ps --format "table {{.Ports}}" | grep -q ":${AVAILABLE_PORT}->" 2>/dev/null; then
            PORT_IN_USE=true
        fi
        
        if [[ "$PORT_IN_USE" == true ]]; then
            warn "Port $AVAILABLE_PORT is in use, trying next port..."
            ((AVAILABLE_PORT++))
        else
            break
        fi
        
        if [[ $AVAILABLE_PORT -gt 6000 ]]; then
            error "No available ports found in range 5678-6000"
        fi
    done
    
    N8N_PORT=$AVAILABLE_PORT
    log "Using port: $N8N_PORT ✓"
}

create_docker_network() {
    log "Creating Docker network..."
    
    if ! docker network ls | grep -q "$DOCKER_NETWORK"; then
        docker network create "$DOCKER_NETWORK" --driver bridge
        log "Created Docker network: $DOCKER_NETWORK"
    else
        log "Docker network $DOCKER_NETWORK already exists ✓"
    fi
}

create_data_directory() {
    log "Creating n8n data directory..."
    mkdir -p "$N8N_DATA_DIR"
    chmod 755 "$N8N_DATA_DIR"
    log "Created data directory: $N8N_DATA_DIR ✓"
}

create_docker_compose() {
    log "Creating docker-compose.yml for n8n on $DOMAIN..."
    
    cat > "$N8N_DATA_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  n8n:
    image: docker.io/n8nio/n8n:latest
    container_name: $N8N_CONTAINER_NAME
    restart: unless-stopped
    ports:
      - "127.0.0.1:${N8N_PORT}:5678"
    environment:
      - N8N_HOST=${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://${DOMAIN}/
      - GENERIC_TIMEZONE=UTC
      - N8N_LOG_LEVEL=info
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
      - N8N_TEMPLATES_ENABLED=true
      - N8N_ONBOARDING_FLOW_DISABLED=false
      - N8N_METRICS=false
      - N8N_ENDPOINT_WEBHOOK=https://${DOMAIN}/webhook/
      - N8N_ENDPOINT_WEBHOOK_TEST=https://${DOMAIN}/webhook-test/
      - N8N_ENDPOINT_WEBHOOK_WAIT=https://${DOMAIN}/webhook-waiting/
      - N8N_EDITOR_BASE_URL=https://${DOMAIN}/
    volumes:
      - ${N8N_CONTAINER_NAME}_data:/home/node/.n8n
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - $DOCKER_NETWORK
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:5678/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=false"
      - "com.docker.compose.project=${N8N_CONTAINER_NAME}"

volumes:
  ${N8N_CONTAINER_NAME}_data:
    name: ${N8N_CONTAINER_NAME}_data

networks:
  $DOCKER_NETWORK:
    external: true
EOF

    log "Docker compose file created for $DOMAIN ✓"
}

create_temp_nginx_config() {
    log "Creating temporary nginx configuration..."
    
    cat > "$NGINX_SITES_DIR/${DOMAIN}" << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    
    client_max_body_size 50M;
    
    location / {
        proxy_pass http://127.0.0.1:${N8N_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_set_header Sec-WebSocket-Extensions \$http_sec_websocket_extensions;
        proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key;
        proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    location /healthz {
        proxy_pass http://127.0.0.1:${N8N_PORT}/healthz;
        access_log off;
    }
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log /var/log/nginx/${DOMAIN}.error.log;
}
EOF

    log "Temporary nginx configuration created ✓"
}

create_final_nginx_config() {
    log "Creating final nginx configuration with SSL..."
    
    cat > "$NGINX_SITES_DIR/${DOMAIN}" << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};
    
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    client_max_body_size 50M;
    
    location / {
        proxy_pass http://127.0.0.1:${N8N_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_set_header Sec-WebSocket-Extensions \$http_sec_websocket_extensions;
        proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key;
        proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    location /healthz {
        proxy_pass http://127.0.0.1:${N8N_PORT}/healthz;
        access_log off;
    }
    
    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log /var/log/nginx/${DOMAIN}.error.log;
}
EOF

    log "Final nginx configuration with SSL created ✓"
}

enable_nginx_site() {
    log "Enabling nginx site..."
    
    ln -sf "$NGINX_SITES_DIR/${DOMAIN}" "$NGINX_ENABLED_DIR/"
    
    if nginx -t; then
        log "Nginx configuration test passed ✓"
        systemctl reload nginx
    else
        error "Nginx configuration test failed."
    fi
}

start_n8n() {
    log "Starting n8n container for $DOMAIN..."
    
    cd "$N8N_DATA_DIR"
    
    if docker ps -a --format "table {{.Names}}" | grep -q "^${N8N_CONTAINER_NAME}$"; then
        log "Stopping existing container..."
        docker stop "$N8N_CONTAINER_NAME" 2>/dev/null || true
        docker rm "$N8N_CONTAINER_NAME" 2>/dev/null || true
    fi
    
    docker-compose up -d
    
    log "Waiting for n8n container to be ready..."
    timeout=120
    while [[ $timeout -gt 0 ]]; do
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "${N8N_CONTAINER_NAME}.*Up"; then
            if docker exec "$N8N_CONTAINER_NAME" wget --no-verbose --tries=1 --spider http://localhost:5678/healthz 2>/dev/null; then
                log "n8n container is ready and healthy ✓"
                break
            fi
        fi
        sleep 5
        ((timeout-=5))
    done
    
    if [[ $timeout -le 0 ]]; then
        warn "n8n took longer than expected to start. Check logs with: docker logs $N8N_CONTAINER_NAME"
    fi
    
    log "n8n Docker container running on port $N8N_PORT ✓"
}

obtain_ssl_certificate() {
    log "Obtaining SSL certificate for $DOMAIN..."
    
    systemctl start nginx
    mkdir -p /var/www/html
    
    if certbot certonly --webroot -w /var/www/html -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL"; then
        log "SSL certificate obtained successfully ✓"
        
        create_final_nginx_config
        
        if nginx -t; then
            systemctl reload nginx
            log "Nginx reloaded with SSL configuration ✓"
        else
            error "SSL nginx configuration test failed"
        fi
    else
        warn "Failed to obtain SSL certificate. Continuing with HTTP only."
    fi
}

create_systemd_service() {
    log "Creating systemd service for n8n..."
    
    cat > "/etc/systemd/system/n8n.service" << EOF
[Unit]
Description=n8n Workflow Automation - Defendx1.com
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$N8N_DATA_DIR
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable n8n.service
    
    log "Systemd service created and enabled ✓"
}

main() {
    check_root
    get_domain_info
    update_system
    install_docker
    install_nginx
    install_certbot
    check_port_conflicts
    create_docker_network
    create_data_directory
    create_docker_compose
    create_temp_nginx_config
    enable_nginx_site
    start_n8n
    obtain_ssl_certificate
    create_systemd_service
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                 Installation Completed!                     ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log "n8n Docker installation completed successfully!"
    log "Domain: https://$DOMAIN"
    log "Container: $N8N_CONTAINER_NAME"
    log "Port: $N8N_PORT"
    log "Data directory: $N8N_DATA_DIR"
    echo ""
    log "Docker Commands:"
    log "- View logs: docker logs $N8N_CONTAINER_NAME"
    log "- View containers: docker ps"
    log "- Stop container: docker stop $N8N_CONTAINER_NAME"
    log "- Start container: docker start $N8N_CONTAINER_NAME"
    log "- Restart container: docker restart $N8N_CONTAINER_NAME"
    echo ""
    log "System Commands:"
    log "- Restart service: systemctl restart n8n"
    log "- Stop service: systemctl stop n8n"
    log "- Start service: systemctl start n8n"
    log "- Check status: systemctl status n8n"
    echo ""
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "${N8N_CONTAINER_NAME}.*Up"; then
        log "✓ n8n is running in Docker container"
        log "✓ Access your n8n instance at: https://$DOMAIN"
    else
        warn "n8n container may not be running properly. Check: docker logs $N8N_CONTAINER_NAME"
    fi
    echo ""
    echo -e "${BLUE}Made by Defendx1.com - https://defendx1.com/${NC}"
}

main "$@"
