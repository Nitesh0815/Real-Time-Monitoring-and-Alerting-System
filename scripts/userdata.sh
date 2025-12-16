#!/bin/bash
set -e

# ------------------------------------------------------------------------------
# Basic system prep
# Update packages and install tools we need for monitoring
# ------------------------------------------------------------------------------

echo "Updating system and installing required packages..."
dnf update -y
dnf install -y wget unzip tar systemd libtool amazon-cloudwatch-agent

# ------------------------------------------------------------------------------
# CloudWatch Agent configuration
# ------------------------------------------------------------------------------

echo "Setting up CloudWatch Agent configuration..."

# Make sure the config directory exists
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc

# Write CloudWatch Agent config
cat <<'EOF' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
    },
    "metrics": {
        "append_dimensions": {
            "InstanceId": "${aws:InstanceId}"
        },
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "/"
                ]
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/cloud-init.log",
                        "log_group_name": "/ec2/cloud-init",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    }
                ]
            }
        }
    }
}
EOF

# Load the config, start the agent, and enable it on boot
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

systemctl daemon-reload
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# ------------------------------------------------------------------------------
# Node Exporter setup
# ------------------------------------------------------------------------------

echo "Installing and configuring Node Exporter..."

# Create a dedicated user if it doesn't already exist
useradd --no-create-home node_exporter || true

cd /opt
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvf node_exporter-1.7.0.linux-amd64.tar.gz
mv node_exporter-1.7.0.linux-amd64 node_exporter
chmod +x /opt/node_exporter/node_exporter

# Systemd service for Node Exporter
cat <<EOF >/etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/opt/node_exporter/node_exporter
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# ------------------------------------------------------------------------------
# Prometheus setup
# ------------------------------------------------------------------------------

echo "Installing and configuring Prometheus..."

# Create Prometheus user if needed
useradd --no-create-home prometheus || true

cd /opt
wget https://github.com/prometheus/prometheus/releases/download/v2.51.0/prometheus-2.51.0.linux-amd64.tar.gz
tar xvf prometheus-2.51.0.linux-amd64.tar.gz
mv prometheus-2.51.0.linux-amd64 prometheus

mkdir -p /opt/prometheus/data
chown -R prometheus:prometheus /opt/prometheus
chmod +x /opt/prometheus/prometheus

# Prometheus configuration file
cat <<'EOF' >/opt/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "node_exporter"
    static_configs:
      - targets: ["localhost:9100"]
EOF

# Systemd service for Prometheus
cat <<EOF >/etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
ExecStart=/opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

# ------------------------------------------------------------------------------
# Grafana setup
# ------------------------------------------------------------------------------

echo "Installing Grafana..."

mkdir -p /etc/yum.repos.d
cat <<EOF >/etc/yum.repos.d/grafana.repo
[grafana]
name=Grafana OSS
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
EOF

dnf install -y grafana

systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

# ------------------------------------------------------------------------------
# Print access details
# ------------------------------------------------------------------------------

echo "Fetching instance IP and printing service URLs..."

# Try public IP first, fall back to private IP if needed
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

echo "======================================"
echo " Monitoring stack installed successfully"
echo " Grafana       : http://$PUBLIC_IP:3000"
echo " Prometheus    : http://$PUBLIC_IP:9090"
echo " Node Exporter : http://$PUBLIC_IP:9100"
echo " Default Grafana Login: admin / admin"
echo "======================================"
