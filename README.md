# n8n Docker Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Supported-blue.svg)](https://www.docker.com/)
[![n8n](https://img.shields.io/badge/n8n-Latest-orange.svg)](https://n8n.io/)
[![SSL](https://img.shields.io/badge/SSL-Let's%20Encrypt-green.svg)](https://letsencrypt.org/)

**One-click n8n workflow automation setup with Docker, SSL, and domain configuration**

Automated installer script that deploys [n8n](https://n8n.io/) workflow automation platform in Docker with SSL certificates, reverse proxy, and custom domain configuration.

## ✨ Features

- 🚀 **One-Click Installation** - Complete automated setup
- 🐳 **Docker Deployment** - Containerized n8n installation
- 🔒 **SSL/HTTPS Ready** - Automatic Let's Encrypt certificates
- 🌐 **Custom Domain Support** - Configure any domain/subdomain
- 🔄 **Auto-Start Service** - Systemd service for boot persistence
- 📊 **Health Monitoring** - Built-in container health checks
- 🛡️ **Security Headers** - Production-ready nginx configuration
- 🔧 **Multi-Instance Support** - Run multiple n8n instances
- 📱 **WebSocket Support** - Full n8n functionality including real-time features

## 🎯 Quick Start

```bash
# Clone the repository
git clone https://github.com/defendx1/n8n.git
cd n8n

# Make the script executable
chmod +x n8n.sh

# Run the installer
sudo ./n8n.sh
```

The script will prompt you for:
- **Domain**: Your domain/subdomain (e.g., `n8n.example.com`)
- **Email**: Email address for SSL certificate

## 📋 Prerequisites

- Ubuntu/Debian server with root access
- Domain pointing to your server's IP address
- Ports 80 and 443 open for SSL certificate validation

**The script automatically installs:**
- Docker & Docker Compose
- Nginx web server
- Certbot (Let's Encrypt)
- Required system packages

## 🔧 What Gets Installed

### Docker Container
- **Image**: `n8nio/n8n:latest`
- **Port**: Auto-detected available port (starting from 5678)
- **Network**: Isolated Docker network
- **Volumes**: Persistent data storage
- **Health Checks**: Automatic container monitoring

### Nginx Configuration
- **Reverse Proxy**: Routes traffic to n8n container
- **SSL/TLS**: Let's Encrypt certificates with auto-renewal
- **Security Headers**: Production-ready security configuration
- **WebSocket Support**: Real-time functionality support

### System Service
- **Systemd Service**: Auto-start on boot
- **Service Management**: Start/stop/restart capabilities
- **Logging**: Centralized log management

## 📁 Directory Structure

```
/opt/n8n_[domain]/
├── docker-compose.yml          # Docker configuration
└── logs/                       # Application logs

/etc/nginx/sites-available/
└── [your-domain]               # Nginx site configuration

/etc/systemd/system/
└── n8n.service                 # Systemd service file
```

## 🎮 Usage Commands

### Docker Commands
```bash
# View container logs
docker logs n8n_[domain]

# View running containers
docker ps

# Stop container
docker stop n8n_[domain]

# Start container
docker start n8n_[domain]

# Restart container
docker restart n8n_[domain]

# Access container shell
docker exec -it n8n_[domain] /bin/sh
```

### System Service Commands
```bash
# Restart n8n service
sudo systemctl restart n8n

# Stop n8n service
sudo systemctl stop n8n

# Start n8n service
sudo systemctl start n8n

# Check service status
sudo systemctl status n8n

# View service logs
sudo journalctl -u n8n -f
```

### Nginx Commands
```bash
# Test nginx configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx

# Restart nginx
sudo systemctl restart nginx

# View nginx logs
sudo tail -f /var/log/nginx/[domain].access.log
sudo tail -f /var/log/nginx/[domain].error.log
```

## 🔧 Configuration

### Environment Variables
The script configures n8n with optimal settings:

- `N8N_HOST`: Your custom domain
- `N8N_PROTOCOL`: HTTPS enabled
- `WEBHOOK_URL`: Properly configured webhooks
- `NODE_ENV`: Production environment
- `N8N_LOG_LEVEL`: Info level logging

### Port Configuration
- **External**: 80 (HTTP) → 443 (HTTPS)
- **Internal**: Auto-detected port (5678+)
- **Container**: 5678 (n8n default)

### SSL Certificate
- **Provider**: Let's Encrypt
- **Auto-Renewal**: Configured via certbot
- **Security**: TLS 1.2+ with strong ciphers

## 🚀 Accessing n8n

After successful installation:

1. **Open your browser** and navigate to `https://your-domain.com`
2. **Complete initial setup** - Create your first admin user
3. **Start building workflows** - n8n is ready to use!

## 🔍 Troubleshooting

### Container Not Starting
```bash
# Check container logs
docker logs n8n_[domain]

# Check if port is available
sudo netstat -tulpn | grep 5678

# Restart the container
docker restart n8n_[domain]
```

### SSL Certificate Issues
```bash
# Check certificate status
sudo certbot certificates

# Renew certificate manually
sudo certbot renew

# Test certificate renewal
sudo certbot renew --dry-run
```

### Nginx Configuration Issues
```bash
# Test nginx configuration
sudo nginx -t

# Check nginx error logs
sudo tail -f /var/log/nginx/error.log

# Reload nginx configuration
sudo systemctl reload nginx
```

### Domain Not Resolving
- Verify DNS records point to your server IP
- Check firewall allows ports 80 and 443
- Ensure domain propagation is complete

## 🔄 Updates

### Updating n8n
```bash
cd /opt/n8n_[domain]

# Pull latest image
docker-compose pull

# Restart with new image
docker-compose up -d
```

### Updating the Script
```bash
cd n8n
git pull origin main
```

## 🏗️ Multi-Instance Setup

The script supports multiple n8n instances on the same server:

```bash
# First instance
sudo ./n8n.sh
# Enter: workflow.company.com

# Second instance  
sudo ./n8n.sh
# Enter: automation.company.com
```

Each instance gets:
- Unique container name
- Separate data directory
- Different port assignment
- Independent SSL certificate

## 🛡️ Security Features

- **SSL/TLS Encryption**: All traffic encrypted
- **Security Headers**: XSS protection, CSRF protection
- **Container Isolation**: Isolated Docker networks
- **Firewall Ready**: Only necessary ports exposed
- **Auto-Updates**: Container restart policies
- **Access Logging**: Comprehensive request logging

## 📊 Monitoring

### Health Checks
The container includes built-in health monitoring:
- **Endpoint**: `/healthz`
- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Retries**: 3 attempts

### Log Locations
- **Container Logs**: `docker logs n8n_[domain]`
- **Nginx Access**: `/var/log/nginx/[domain].access.log`
- **Nginx Error**: `/var/log/nginx/[domain].error.log`
- **System Service**: `journalctl -u n8n`

## 🤝 Contributing

We welcome contributions! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This script is provided as-is. Always review scripts before running them on production servers. Test in a development environment first.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/defendx1/n8n/issues)
- **Documentation**: [n8n Official Docs](https://docs.n8n.io/)
- **Community**: [n8n Community](https://community.n8n.io/)

## 🔗 Related Links

- [n8n Official Website](https://n8n.io/)
- [n8n Docker Documentation](https://docs.n8n.io/hosting/installation/docker/)
- [Docker Documentation](https://docs.docker.com/)
- [Let's Encrypt](https://letsencrypt.org/)

---

**Made with ❤️ by [Defendx1.com](https://defendx1.com/)**

---

### 📈 Stats

![GitHub stars](https://img.shields.io/github/stars/defendx1/n8n?style=social)
![GitHub forks](https://img.shields.io/github/forks/defendx1/n8n?style=social)
![GitHub issues](https://img.shields.io/github/issues/defendx1/n8n)
![GitHub last commit](https://img.shields.io/github/last-commit/defendx1/n8n)
