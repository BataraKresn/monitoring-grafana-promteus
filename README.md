# Infrastructure Monitoring Stack

This project provides a comprehensive monitoring solution for:
- Server system monitoring using node-exporter with Tailscale IPs
- MongoDB single instance monitoring 
- Docker container monitoring on remote servers
- PM2 services monitoring on remote servers

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Prometheus    │────│   Grafana       │────│  Alertmanager   │
│   (Collector)   │    │   (Dashboard)   │    │   (Alerts)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │
         │
    ┌────┼────┐
    │    │    │
┌───▼───┐│ ┌──▼──┐ ┌─────────┐
│Node   ││ │Docker│ │MongoDB  │
│Export ││ │cAdvis│ │Single   │
│(9100) ││ │(8080)│ │(27017)  │
└───────┘│ └─────┘ └─────────┘
         │
   ┌─────▼─────┐
   │PM2 Export │
   │  (9209)   │
   └───────────┘
```

## Services

### Core Monitoring Stack
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert management and notifications

### Monitored Targets
1. **Server System Metrics**: CPU, memory, disk, network via Node Exporter
2. **MongoDB Single Instance**: Database monitoring and performance
3. **Docker Containers**: Container health and resource usage via cAdvisor
4. **PM2 Services**: Node.js application monitoring

## Quick Start

### 1. Prerequisites
- Docker and Docker Compose installed
- Tailscale network configured
- Target servers accessible via Tailscale IPs

### 2. Configuration

#### Update Target Files
Edit the following files with your actual IPs and endpoints:

**config/prometheus/node_targets.yml**
```yaml
- targets:
  - "100.x.x.x:9100"    # Node Exporter on Server 1
  - "100.x.x.x:9100"    # Node Exporter on Server 2
```

**config/prometheus/mongodb_targets.yml**
```yaml
- targets:
  - "100.x.x.x:27017"  # MongoDB Single Instance
  - "100.x.x.x:9216"   # MongoDB Exporter (optional)
```

**config/prometheus/docker_targets.yml**
```yaml
- targets:
  - "100.x.x.x:8080"   # cAdvisor for Docker metrics
```

**config/prometheus/pm2_targets.yml**
```yaml
- targets:
  - "100.x.x.x:9209"   # PM2 metrics endpoint (pm2-prometheus-exporter)
```

### 3. Start Services

```bash
# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

### 4. Access Interfaces

- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093

## Quick Setup with Docker Commands

### Single Docker Command Setup

If you want to quickly setup monitoring agents on any server:

```bash
# Quick node exporter setup
docker run -d \
  --name node_exporter \
  --restart unless-stopped \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  prom/node-exporter:latest \
  --path.rootfs=/host

# Test it
curl http://localhost:9100/metrics | head -10
```

### Complete Monitoring Agent Setup (One Command)

Run this on target servers to install all monitoring agents:

```bash
# Create monitoring agents setup (use the installer script)
./install-agents.sh
```

Or manually:

```bash
# Create directory for configs
mkdir -p ~/monitoring-agents && cd ~/monitoring-agents

# Create docker-compose file for all agents
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node_exporter
    restart: unless-stopped
    network_mode: host
    pid: host
    volumes:
      - '/:/host:ro,rslave'
    command:
      - '--path.rootfs=/host'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
      
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
EOF

# Start all agents
docker-compose up -d

# Verify all are running
docker-compose ps
```

## Target Server Setup

### Option 1: Installing Node Exporter using Docker (Recommended)

#### On Remote Servers (via Tailscale)

**1. Using Docker Run Command:**
```bash
# Run node exporter container for system metrics
docker run -d \
  --name node_exporter \
  --restart unless-stopped \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  -p 9100:9100 \
  prom/node-exporter:latest \
  --path.rootfs=/host \
  --collector.filesystem.ignored-mount-points='^/(sys|proc|dev|host|etc)($$|/)' \
  --collector.netdev.ignored-devices='^(veth|docker|br-).*'

# Run cAdvisor for Docker container metrics
docker run -d \
  --name cadvisor \
  --restart unless-stopped \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --volume=/dev/disk/:/dev/disk:ro \
  --publish=8080:8080 \
  --privileged \
  gcr.io/cadvisor/cadvisor:latest
```

**2. Using Docker Compose (Alternative):**
```yaml
# Create docker-compose.yml on target server
version: '3.8'
services:
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node_exporter
    restart: unless-stopped
    network_mode: host
    pid: host
    ports:
      - "9100:9100"
    volumes:
      - '/:/host:ro,rslave'
    command:
      - '--path.rootfs=/host'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro  
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
```

**Verify Installation:**
```bash
# Check if containers are running
docker ps | grep -E "(node_exporter|cadvisor)"

# Test node exporter
curl http://localhost:9100/metrics | head -20

# Test cAdvisor 
curl http://localhost:8080/metrics | head -20

# Check specific metrics
curl -s http://localhost:9100/metrics | grep "node_cpu_seconds_total"
curl -s http://localhost:8080/metrics | grep "container_cpu_usage_seconds_total"
```

### Option 2: Installing Node Exporter Binary (Traditional)

On each server you want to monitor via Tailscale:

1. **Download and Install Node Exporter**:
```bash
# Download node exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz

# Extract
tar xzf node_exporter-1.6.1.linux-amd64.tar.gz
cd node_exporter-1.6.1.linux-amd64

# Copy binary
sudo cp node_exporter /usr/local/bin/

# Create user
sudo useradd --no-create-home --shell /bin/false node_exporter
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
```

2. **Create Systemd Service**:
```bash
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --collector.filesystem.ignored-mount-points='^/(sys|proc|dev|host|etc)($$|/)'

[Install]
WantedBy=multi-user.target
EOF
```

3. **Start Service**:
```bash
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter
```

### Docker Monitoring Setup

#### Option 1: Using Docker Container (Recommended)

On servers with Docker containers to monitor, you can run node-exporter and cAdvisor:

**1. Node Exporter for System Metrics:**
```bash
docker run -d \
  --name node_exporter \
  --restart unless-stopped \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  prom/node-exporter:latest \
  --path.rootfs=/host
```

**2. cAdvisor for Container Metrics:**
```bash
docker run -d \
  --name cadvisor \
  --restart unless-stopped \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --volume=/dev/disk/:/dev/disk:ro \
  --publish=8080:8080 \
  --detach=true \
  gcr.io/cadvisor/cadvisor:latest
```

**3. Docker Compose for Multiple Exporters:**
```yaml
# docker-compose.yml for monitoring agents
version: '3.8'
services:
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node_exporter
    restart: unless-stopped
    network_mode: host
    pid: host
    volumes:
      - '/:/host:ro,rslave'
    command:
      - '--path.rootfs=/host'

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro

  blackbox-exporter:
    image: prom/blackbox-exporter:latest
    container_name: blackbox_exporter
    restart: unless-stopped
    ports:
      - "9115:9115"
    volumes:
      - ./blackbox-config.yml:/etc/blackbox_exporter/config.yml:ro
```

#### Option 2: Enable Docker Daemon Metrics (Alternative)

On servers with Docker containers to monitor:

1. **Enable Docker Metrics**:
Edit `/etc/docker/daemon.json`:
```json
{
  "metrics-addr": "0.0.0.0:9323",
  "experimental": true
}
```

2. **Restart Docker**:
```bash
sudo systemctl restart docker
```

### PM2 Monitoring Setup

#### Option 1: Using Docker Container (Recommended)

**1. PM2 Prometheus Exporter via Docker:**
```bash
# Run PM2 exporter container
docker run -d \
  --name pm2_exporter \
  --restart unless-stopped \
  -p 9209:9209 \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v ~/.pm2:/root/.pm2:ro \
  --network host \
  keymetrics/pm2-prometheus-exporter:latest
```

**2. Using Node.js Container with PM2 Exporter:**
```yaml
# docker-compose.yml for PM2 monitoring
version: '3.8'
services:
  pm2-exporter:
    image: node:16-alpine
    container_name: pm2_exporter
    restart: unless-stopped
    ports:
      - "9209:9209"
    volumes:
      - ~/.pm2:/root/.pm2:ro
    working_dir: /app
    command: >
      sh -c "
        npm install -g pm2-prometheus-exporter &&
        pm2-prometheus-exporter --port 9209
      "
```

#### Option 2: Traditional Installation

On servers with PM2 services:

1. **Install PM2 Prometheus Exporter**:
```bash
npm install -g pm2-prometheus-exporter
```

2. **Start Exporter**:
```bash
pm2-prometheus-exporter --port 9209
```

3. **Or as PM2 Process**:
```bash
pm2 start pm2-prometheus-exporter --name pm2-exporter -- --port 9209
pm2 save
```

### MongoDB Monitoring Setup

For MongoDB single instance monitoring:

1. **MongoDB Exporter using Docker** (recommended):
```bash
# Run MongoDB exporter
docker run -d \
  --name mongodb_exporter \
  --restart unless-stopped \
  -p 9216:9216 \
  percona/mongodb_exporter:0.37 \
  --mongodb.uri="mongodb://100.73.222.94:27017"
```

2. **MongoDB Exporter Binary Installation**:
```bash
# Download mongodb_exporter
wget https://github.com/percona/mongodb_exporter/releases/download/v0.37.0/mongodb_exporter-0.37.0.linux-amd64.tar.gz
tar xzf mongodb_exporter-0.37.0.linux-amd64.tar.gz
sudo cp mongodb_exporter /usr/local/bin/

# Create service
sudo tee /etc/systemd/system/mongodb_exporter.service > /dev/null <<EOF
[Unit]
Description=MongoDB Exporter
After=network.target

[Service]
Type=simple
User=mongodb
ExecStart=/usr/local/bin/mongodb_exporter --mongodb.uri=mongodb://localhost:27017
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable mongodb_exporter
sudo systemctl start mongodb_exporter
```

## Configuration Details

### Blackbox Exporter Modules

The blackbox exporter is configured with the following modules:

- **http_2xx**: HTTP GET requests expecting 2xx response
- **http_post_2xx**: HTTP POST requests expecting 2xx response
- **tcp_connect**: TCP connection testing
- **icmp**: ICMP ping testing

### Prometheus Scrape Jobs

- **blackbox-http**: HTTP endpoint monitoring via blackbox exporter
- **blackbox-tcp**: TCP port monitoring for databases
- **docker**: Docker daemon metrics
- **pm2**: PM2 process metrics
- **mongodb**: MongoDB metrics (if using mongodb_exporter)

### Alert Rules

Configured alerts for:
- Service down detection
- High response times
- Container failures
- PM2 process crashes
- MongoDB replica set issues

## Monitoring Dashboard

The Grafana dashboard includes:

1. **Server Status Table**: Shows up/down status of all monitored servers
2. **Response Times Graph**: HTTP response times over time
3. **Docker Container Status**: Health status of Docker containers
4. **PM2 Services Status**: Status of PM2 managed processes
5. **MongoDB Replica Set Status**: MongoDB cluster health

## Troubleshooting

### Common Issues

1. **Targets not appearing in Prometheus**:
   - Check target file syntax
   - Verify Tailscale connectivity
   - Check firewall rules

2. **Blackbox exporter connection refused**:
   - Verify target service is running
   - Check network connectivity
   - Verify port configurations

3. **Docker metrics not available**:
   - Ensure Docker daemon has metrics enabled
   - Check Docker daemon configuration
   - Verify port 9323 is accessible

4. **PM2 metrics missing**:
   - Verify pm2-prometheus-exporter is running
   - Check port 9209 accessibility
   - Confirm PM2 processes are running

### Useful Commands

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Test blackbox exporter manually
curl "http://localhost:9115/probe?module=http_2xx&target=http://example.com"

# View Prometheus config
docker-compose exec prometheus cat /etc/prometheus/prometheus.yml

# Restart services
docker-compose restart prometheus grafana alertmanager blackbox-exporter
```

## Security Considerations

1. **Network Security**:
   - Use Tailscale for secure networking
   - Restrict port access to monitoring subnet only
   - Enable authentication where possible

2. **Grafana Security**:
   - Change default admin password
   - Configure proper user roles
   - Enable SSL/TLS for production

3. **Alert Security**:
   - Secure webhook endpoints
   - Use encrypted channels for sensitive alerts
   - Implement proper alert routing

## Maintenance

### Regular Tasks

1. **Update configurations** when adding/removing servers
2. **Monitor disk usage** for Prometheus data retention
3. **Update dashboard queries** as infrastructure changes
4. **Review and tune alert thresholds** based on baseline metrics
5. **Backup Grafana dashboards** and Prometheus configuration

### Scaling Considerations

- **Prometheus retention**: Adjust `--storage.tsdb.retention.time` for data retention needs
- **Scrape intervals**: Balance between data granularity and resource usage
- **Alert routing**: Configure appropriate notification channels for different alert severities

## Additional Files

This repository includes helper files for easy setup:

- **`install-agents.sh`**: Automated installer script for monitoring agents on target servers
- **`standalone-blackbox-config.yml`**: Standalone blackbox exporter configuration
- All target configuration files are in `config/prometheus/` directory

### Quick Remote Server Setup

**Method 1: Using the installer script**
```bash
# Copy installer to target server
scp install-agents.sh user@target-server:~/
ssh user@target-server
chmod +x install-agents.sh
./install-agents.sh
```

**Method 2: One-liner installation**
```bash
# Download and run installer (if hosted on GitHub)
curl -fsSL https://raw.githubusercontent.com/BataraKresn/monitoring-grafana-promteus/main/install-agents.sh | bash
```

**Method 3: Manual Docker commands**
```bash
# Just blackbox exporter
docker run -d --name blackbox_exporter --restart unless-stopped -p 9115:9115 prom/blackbox-exporter:latest

# Full monitoring stack
mkdir monitoring && cd monitoring
curl -O https://raw.githubusercontent.com/BataraKresn/monitoring-grafana-promteus/main/standalone-blackbox-config.yml
docker run -d --name blackbox_exporter --restart unless-stopped -p 9115:9115 -v $(pwd)/standalone-blackbox-config.yml:/etc/blackbox_exporter/config.yml:ro prom/blackbox-exporter:latest --config.file=/etc/blackbox_exporter/config.yml
```

## Support

For issues or questions:
1. Check Prometheus targets page: http://localhost:9090/targets
2. Review service logs: `docker-compose logs <service-name>`
3. Verify network connectivity between monitoring and target servers
4. Check Tailscale connectivity: `tailscale ping <target-ip>`
5. Test blackbox exporter manually: `curl "http://target-ip:9115/probe?module=http_2xx&target=http://example.com"`
