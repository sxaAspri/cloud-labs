# SNS — el canal de notificaciones
resource "aws_sns_topic" "security_alerts" {
  name = "self-healing-alerts"

  tags = {
    Name    = "self-healing-alerts"
    Project = "self-healing-aws"
  }
}

# Suscripción — tu email donde llegan las alertas
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = "TU_EMAIL_AQUI"
}

# Output
output "sns_topic_arn" {
  value       = aws_sns_topic.security_alerts.arn
  description = "ARN del topic SNS"
}
