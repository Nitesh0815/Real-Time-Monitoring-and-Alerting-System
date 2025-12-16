# ------------------------------------------------------------------------------
# 1. AWS Configuration
# ------------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region to deploy resources in (e.g., eu-west-1)."
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "A short name used as a prefix for all resources."
  type        = string
  default     = "ObservabilityStack"
}

# ------------------------------------------------------------------------------
# 2. EC2 Configuration
# ------------------------------------------------------------------------------
variable "instance_type" {
  description = "The EC2 instance type for the monitoring server."
  type        = string
  default     = "t3.medium"
}

variable "key_pair_name" {
  description = "The name of the existing EC2 Key Pair for SSH access."
  type        = string
}

# ------------------------------------------------------------------------------
# 3. Alerting Configuration
# ------------------------------------------------------------------------------
variable "admin_email" {
  description = "Email address for SNS subscription (for email alerts/confirmation)."
  type        = string
}

variable "slack_channel_name" {
  description = "The name of the Slack channel to send alerts to (e.g., #alerts)."
  type        = string
  default     = "monitoring-alerts"
}

variable "slack_bot_token" {
  description = "The OAuth token for the Slack Bot (sensitive credential)."
  type        = string
  sensitive   = true # Marks variable as sensitive to prevent logging the value
}