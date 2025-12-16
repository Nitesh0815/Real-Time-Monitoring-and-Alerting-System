output "monitoring_server_ip" {
  description = "Public IP address of the Monitoring Server (for SSH and direct access)."
  value       = aws_instance.monitoring_server.public_ip
}

output "grafana_url" {
  description = "Grafana Access URL (Default login: admin/admin). Access via port 3000."
  value       = "http://${aws_instance.monitoring_server.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus Web UI URL. Access via port 9090."
  value       = "http://${aws_instance.monitoring_server.public_ip}:9090"
}

output "sns_topic_arn" {
  description = "The ARN of the SNS Topic used for routing CloudWatch alerts."
  value       = aws_sns_topic.cloudwatch_alerts.arn
}

output "slack_lambda_function_name" {
  description = "The name of the AWS Lambda function handling Slack alerts."
  value       = aws_lambda_function.cloudwatch_to_slack.function_name
}