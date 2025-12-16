# 3️⃣ Real-Time Monitoring and Alerting System (Full Observability)

## Introduction

The **Real-Time Monitoring and Alerting System (Full Observability)** is a production-ready monitoring solution designed to give complete visibility into cloud-based workloads running on AWS. It combines **AWS-native monitoring** with **open-source observability tools** to provide real-time insights, proactive alerting, and centralized logging — all without manual server access.

This project demonstrates how modern cloud environments can be monitored automatically using infrastructure-as-code and bootstrapped installations. It is ideal for **cloud engineers, DevOps teams, and support teams** who want to detect issues early, reduce downtime, and operate systems with confidence.

> 💡 **Why companies love this approach**: Support and Cloud Engineers spend nearly **50% of their time monitoring and fixing issues**. This system automates monitoring and alerting so teams can focus on building instead of firefighting.

---

## Features

### 🔍 Infrastructure & Application Monitoring

- **EC2 CPU, Memory, and Disk Monitoring** using CloudWatch Agent and Prometheus Node Exporter
- **Custom CloudWatch Metrics** for enhanced visibility beyond default AWS metrics
- **Prometheus** for time-series metric collection
- **Grafana** for real-time visualization and dashboards

### 🚨 Alerting & Notifications

- Threshold-based alerts for CPU, memory, disk, and application health
- Notifications via:
  - 📩 Email
  - 📱 SMS
  - 💬 Slack
- Alerts can be triggered from CloudWatch Alarms or Grafana Alerting rules

### 📜 Centralized Logging

- **CloudWatch Logs** for AWS-native log aggregation
- Optional support for **ELK Stack (Elasticsearch, Logstash, Kibana)** for advanced log analysis
- Application and system logs are centrally searchable and retained

### ⚙️ Fully Automated Setup (No SSH Required)

- All required software is installed using **user-data.sh** at instance launch
- Automatically installs and configures:
  - CloudWatch Agent
  - Prometheus
  - Grafana
  - Node.js + Express (sample application)
- Eliminates the need for manual SSH access to EC2 instances

---

## Architecture Overview

- **Terraform (main.tf)** provisions the infrastructure
- **EC2 Instance** runs monitoring tools and sample application
- **CloudWatch** collects metrics and logs
- **Prometheus** scrapes system and application metrics
- **Grafana** visualizes metrics using a prebuilt dashboard
- **SNS / Webhooks** deliver alerts to Email, SMS, and Slack

---

## Project Implementation Approaches

This project was implemented using **two complementary approaches** to demonstrate both foundational AWS knowledge and modern Infrastructure as Code (IaC) practices.

### 1️⃣ Manual AWS Resource Creation (Hands-on Approach)

In the initial phase, all AWS resources were created **manually using the AWS Management Console**. This helped in building a strong understanding of how each service works individually and how they integrate in a real-world monitoring setup.

Manually created components included:

- EC2 instances for hosting monitoring tools
- IAM roles and policies for CloudWatch and logging access
- CloudWatch metrics, alarms, and log groups
- SNS topics for Email, SMS, and Slack notifications
- Security Groups and networking configurations

This approach provided deep insight into AWS service behavior, dependencies, and real-time troubleshooting.

### 2️⃣ Terraform-Based Automation (Production Approach)

After validating the architecture manually, the entire infrastructure was **re-created using Terraform** to ensure repeatability, scalability, and consistency.

Benefits of the Terraform approach:

- Infrastructure defined as code (`main.tf`)
- Easy environment replication (dev / test / prod)
- Reduced human error
- Faster deployments and teardown

Both approaches together demonstrate **practical AWS expertise + DevOps automation skills**, which is highly valued in real-world cloud engineering roles.

---

## Installation

### Prerequisites

- AWS Account
- Terraform installed (v1.x recommended)
- Basic understanding of AWS and monitoring concepts

### Steps

1. **Clone the Repository**

   ```bash
   git clone https://github.com/your-username/real-time-monitoring-system.git
   cd real-time-monitoring-system
   ```

2. **Review **`` The `main.tf` file defines:

   - EC2 instance provisioning
   - IAM roles and permissions
   - Security groups
   - User data configuration
   - CloudWatch integration

3. **Automated Bootstrapping with **``

   - Installs CloudWatch Agent, Prometheus, Grafana, and Node Express
   - Configures services to start automatically on boot
   - Applies monitoring and logging configuration

   ✅ No SSH access is required at any stage.

4. **Deploy the Infrastructure**

   ```bash
   terraform init
   terraform apply
   ```

5. **Confirm Deployment**

   - Terraform outputs the EC2 public IP or DNS
   - All services are available once the instance is running

---

## Configuration Before Use

Before deploying this project in your own AWS account, a few **environment-specific values** must be updated to ensure security and proper integration.

### 🔐 Terraform Configuration Updates

When using this project, you **must update or provide the following values** in Terraform files (`variables.tf`, `terraform.tfvars`, or directly in `main.tf` as applicable):

#### 1️⃣ EC2 Key Pair

- Replace the key pair name with **your existing AWS EC2 key pair**
- This is required if you want optional SSH access (even though SSH is not mandatory)

```hcl
key_name = "your-key-pair-name"
```

> ⚠️ The key pair must already exist in the selected AWS region.

---

#### 2️⃣ Slack Alerting Configuration

- Update Slack Webhook URL or token used for alert notifications
- This value should **never be hardcoded** in public repositories

Recommended options:

- Terraform variables
- AWS Systems Manager Parameter Store
- Environment variables

```hcl
slack_webhook_url = "https://hooks.slack.com/services/XXX/YYY/ZZZ"
```

---

#### 3️⃣ Email & SMS Alerts (SNS)

- Update email addresses and phone numbers used in SNS subscriptions
- SMS alerts may require enabling SMS permissions in your AWS account

```hcl
alert_email = "your-email@example.com"
alert_phone = "+91XXXXXXXXXX"
```

---

#### 4️⃣ AWS Region

- Ensure the AWS region matches your deployment preference and available resources

```hcl
aws_region = "ap-south-1"
```

---

#### 5️⃣ Grafana Credentials

- Default Grafana credentials are set during installation
- It is **strongly recommended** to change them after first login

Credentials are configured via:

- `user-data.sh`
- Grafana environment variables

---

#### 6️⃣ Prometheus & Alert Thresholds

- CPU, memory, and disk alert thresholds can be adjusted in:
  - CloudWatch Alarms
  - Grafana Alerting rules
  - Prometheus configuration files

This allows teams to tune alerts based on workload behavior.

---

#### 7️⃣ IAM Permissions

- IAM roles and policies are created automatically
- If deploying in a restricted AWS account, ensure permissions for:
  - CloudWatch
  - EC2
  - SNS
  - Logs

---

### 🔒 Security Best Practices

- Do **not** commit secrets (Slack tokens, passwords) to GitHub
- Use `.tfvars` files and add them to `.gitignore`
- Prefer AWS SSM Parameter Store or Secrets Manager

---

## Usage

### Accessing Grafana

- Open a browser and navigate to:
  ```
  http://<EC2-PUBLIC-IP>:3000
  ```
- Default credentials can be changed after first login

### Grafana Dashboard

- Dashboards are imported automatically using a **JSON dashboard file**
- The JSON file defines:
  - CPU, memory, and disk panels
  - Prometheus data sources
  - Alert thresholds

This ensures consistent dashboards across environments.

### Monitoring Metrics

- **CloudWatch**: View AWS-native metrics and custom metrics
- **Prometheus**: Explore raw time-series metrics
- **Grafana**: Visualize everything in a single pane of glass

### Alerts

- Alerts trigger automatically when thresholds are breached
- Notifications are sent via Email, SMS, or Slack
- Alerting rules can be customized in CloudWatch or Grafana

---

## Project Structure

```text
.
├── main.tf                 # Terraform infrastructure definition
├── variables.tf            # Input variables
├── outputs.tf              # Deployment outputs
├── user-data.sh            # Automated installation & configuration
├── grafana-dashboard.json  # Prebuilt Grafana dashboard
└── README.md               # Project documentation
```

---

## Contributing

Contributions are welcome and encouraged 🎉

To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes with clear commits
4. Submit a pull request with a detailed description

Possible contribution ideas:

- Additional Grafana dashboards
- Advanced alerting rules
- ELK stack integration
- Kubernetes or ECS support

---

## Conclusion

This project showcases a **real-world, enterprise-grade monitoring and alerting system** built using industry-standard tools. By combining AWS services with open-source observability platforms and full automation via Terraform and user data scripts, it delivers **full observability with minimal operational overhead**.

Whether you are a beginner learning cloud monitoring or an experienced engineer designing scalable systems, this project provides a strong, practical foundation.

---

⭐ If you find this project useful, consider starring the repository and sharing it with your team.