#!/bin/bash

# Monitoring Agents Installer Script
# This script installs node exporter, cadvisor for server monitoring

set -e

echo "🚀 Installing Server Monitoring Agents (Node Exporter + cAdvisor)..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Create monitoring directory
MONITORING_DIR="$HOME/monitoring-agents"
mkdir -p $MONITORING_DIR
cd $MONITORING_DIR

echo "📁 Created monitoring directory: $MONITORING_DIR"

# Get server IP for identification
SERVER_IP=$(hostname -I | awk '{print $1}')
SERVER_NAME=$(hostname)

echo "📍 Server: $SERVER_NAME ($SERVER_IP)"

# Create docker-compose file for monitoring agents
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node_exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    network_mode: host
    pid: host
    volumes:
      - '/:/host:ro,rslave'
    command:
      - '--path.rootfs=/host'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)(\$\$|/)'
      - '--collector.netdev.ignored-devices=^(veth|docker|br-).*'
      - '--collector.textfile.directory=/host/var/lib/node_exporter'
      
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

  pm2-exporter:
    image: node:18-alpine
    container_name: pm2_exporter
    restart: unless-stopped
    ports:
      - "9209:9209"
    volumes:
      - ~/.pm2:/root/.pm2:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    working_dir: /app
    command: >
      sh -c "
        npm install -g pm2-prometheus-exporter &&
        pm2-prometheus-exporter --port 9209 --host 0.0.0.0
      "
    privileged: true
    devices:
      - /dev/kmsg:/dev/kmsg
    command:
      - '--housekeeping_interval=10s'
      - '--docker_only=true'
      - '--disable_metrics=accelerator,cpu_topology,disk,memory_numa,tcp,udp,percpu,sched,process,hugetlb,referenced_memory,resctrl,cpuset,advtcp,memory_numa'
EOF

echo "📝 Created configuration files"

# Start services
echo "🔄 Starting monitoring services..."
docker-compose up -d

# Wait a moment for services to start
sleep 5

echo "✅ Monitoring agents installed successfully!"
echo ""
echo "📊 Services running:"
docker-compose ps

echo ""
echo "🌐 Access endpoints:"
echo "  - Node Exporter:     http://$(hostname -I | awk '{print $1}'):9100"
echo "  - cAdvisor:          http://$(hostname -I | awk '{print $1}'):8080"
echo "  - PM2 Exporter:      http://$(hostname -I | awk '{print $1}'):9209"

echo ""
echo "🔧 Test endpoints:"
echo "curl http://localhost:9100/metrics  # Node Exporter"
echo "curl http://localhost:8080/metrics  # cAdvisor" 
echo "curl http://localhost:9209/metrics  # PM2 Exporter"

echo ""
echo "🔧 Useful commands:"
echo "  - View logs:    docker-compose logs -f"
echo "  - Stop all:     docker-compose down"
echo "  - Restart all:  docker-compose restart"
echo "  - Update all:   docker-compose pull && docker-compose up -d"