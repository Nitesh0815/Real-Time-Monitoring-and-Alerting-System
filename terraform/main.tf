# Configure AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ------------------------------------------------------------------------------
# 1. Networking (Default VPC and Security Group)
# ------------------------------------------------------------------------------

# Use default VPC and find available subnet
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "monitoring_sg" {
  name        = "${var.project_name}-SG"
  description = "Allow access to Prometheus (9090), Grafana (3000), and SSH (22)"
  vpc_id      = data.aws_vpc.default.id

  # SSH Access (Screenshot 19)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Restrict this IP range in a production environment.
  }

  # Grafana Access (Screenshot 19)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Prometheus Access (Screenshot 19)
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Node Exporter Access (Screenshot 19)
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic allowed (for updates, metrics export, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-SG"
  }
}

# ------------------------------------------------------------------------------
# 2. IAM Role for CloudWatch Agent (Screenshots 11-16)
# ------------------------------------------------------------------------------

resource "aws_iam_role" "ec2_monitoring_role" {
  name = "${var.project_name}-EC2-CW-Agent-Role"

  # Standard EC2 AssumeRole Trust Policy
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Attach the managed policy required for the CloudWatch Agent
resource "aws_iam_role_policy_attachment" "cw_policy_attachment" {
  role       = aws_iam_role.ec2_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Create an Instance Profile to attach the role to the EC2 instance
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-EC2-Profile"
  role = aws_iam_role.ec2_monitoring_role.name
}

# ------------------------------------------------------------------------------
# 3. EC2 Instance (Screenshots 22-28)
# ------------------------------------------------------------------------------

resource "aws_instance" "monitoring_server" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.monitoring_sg.id]
  subnet_id                   = data.aws_subnets.default.ids[0]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name # Attach IAM Role (Screenshot 24)

  # Inject the bootstrap script for automated setup (Screenshot 25)
  user_data = file("${path.module}/../scripts/userdata.sh")

  tags = {
    Name    = "Dev-Monitoring"
    Project = var.project_name
  }
}

# ------------------------------------------------------------------------------
# 4. Alerting Infrastructure (SNS, Lambda, CloudWatch Alarms)
# The SNS topic setup is separate from the Lambda and Alarms, which are grouped
# ------------------------------------------------------------------------------

# --- SNS Topic (Screenshots 39-41) ---
resource "aws_sns_topic" "cloudwatch_alerts" {
  name = "CloudWatchAlerts"
}

# --- Email Subscription for Testing (Screenshots 42-43) ---
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.cloudwatch_alerts.arn
  protocol  = "email"
  endpoint  = var.admin_email
}

# --- Lambda Execution Role ---
# This role allows Lambda to run and to interact with SNS
resource "aws_iam_role" "slack_lambda_role" {
  name = "${var.project_name}-Slack-Lambda-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# Lambda Basic Execution Policy (logs and function invocation)
resource "aws_iam_policy" "lambda_logging_policy" {
  name = "${var.project_name}-Lambda-Logging-Policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logging_attach" {
  role       = aws_iam_role.slack_lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}

data "archive_file" "slack_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/slack_alert_handler/lambda.py"
  output_path = "${path.module}/../lambda/slack_alert_handler/lambda_package.zip"
}

# --- Lambda Function (Screenshots 66-73) ---
resource "aws_lambda_function" "cloudwatch_to_slack" {
  filename      = data.archive_file.slack_lambda_zip.output_path
  function_name = "CloudWatchToSlack"
  role          = aws_iam_role.slack_lambda_role.arn
  handler       = "lambda.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30 # Time in seconds

  # Inject the Slack Webhook URL securely via Environment Variable (Screenshot 73)
  environment {
    variables = {
      SLACK_BOT_TOKEN    = var.slack_bot_token
      SLACK_CHANNEL_NAME = var.slack_channel_name
    }
  }

  source_code_hash = data.archive_file.slack_lambda_zip.output_base64sha256
}

# Grant SNS permission to invoke the Lambda function
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudwatch_to_slack.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.cloudwatch_alerts.arn
}

# --- SNS Subscription to Lambda (Screenshot 75) ---
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.cloudwatch_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.cloudwatch_to_slack.arn
}

# ------------------------------------------------------------------------------
# 5. CloudWatch Alarms (Screenshots 45-62)
# Using `aws_cloudwatch_metric_alarm` for CPU, Disk, and Memory
# ------------------------------------------------------------------------------


# --- CPU Alarm (Screenshots 46-50) ---
resource "aws_cloudwatch_metric_alarm" "cpu_high_alarm" {
  alarm_name          = "EC2-CPU-Usage-High"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "cpu_usage_user"
  namespace           = "CWAgent"
  period              = "60" # 1 minute
  statistic           = "Average"
  threshold           = "80" # 80% threshold (Screenshot 48)
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.monitoring_server.id
  }

  alarm_actions = [aws_sns_topic.cloudwatch_alerts.arn] # Connects to SNS (Screenshot 49)
  ok_actions    = [aws_sns_topic.cloudwatch_alerts.arn]
}

# --- Disk Alarm (Screenshots 51-55) ---
resource "aws_cloudwatch_metric_alarm" "disk_high_alarm" {
  alarm_name          = "EC2-Disk-Usage-High"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = "60"
  statistic           = "Average"
  threshold           = "80" # 80% threshold (Screenshot 53)
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.monitoring_server.id
    path       = "/"
    fstype     = "ext4" # Adjust if using a different fstype
  }

  alarm_actions = [aws_sns_topic.cloudwatch_alerts.arn]
  ok_actions    = [aws_sns_topic.cloudwatch_alerts.arn]
}

# --- Memory Alarm (Screenshots 56-61) ---
resource "aws_cloudwatch_metric_alarm" "memory_high_alarm" {
  alarm_name          = "EC2-Memory-Usage-High"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = "60"
  statistic           = "Average"
  threshold           = "80" # 80% threshold (Screenshot 58)
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.monitoring_server.id
  }

  alarm_actions = [aws_sns_topic.cloudwatch_alerts.arn]
  ok_actions    = [aws_sns_topic.cloudwatch_alerts.arn]
}