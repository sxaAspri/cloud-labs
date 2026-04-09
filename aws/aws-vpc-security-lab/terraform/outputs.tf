# --- VPC ---
output "vpc_id" {
  description = "ID de la VPC principal"
  value       = aws_vpc.main.id
}

# --- Subnets ---
output "public_subnet_ids" {
  description = "IDs de las subnets públicas"
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "app_subnet_ids" {
  description = "IDs de las subnets de aplicación"
  value       = [aws_subnet.app_a.id, aws_subnet.app_b.id]
}

output "data_subnet_ids" {
  description = "IDs de las subnets de datos"
  value       = [aws_subnet.data_a.id, aws_subnet.data_b.id]
}

# --- EC2 ---
output "bastion_public_ip" {
  description = "IP pública del bastion host"
  value       = aws_instance.bastion.public_ip
}

output "app_private_ip" {
  description = "IP privada de la EC2 de aplicación"
  value       = aws_instance.app.private_ip
}

output "data_private_ip" {
  description = "IP privada de la EC2 de datos"
  value       = aws_instance.data.private_ip
}

# --- Flow Logs ---
output "flow_log_group" {
  description = "Nombre del Log Group de Flow Logs"
  value       = aws_cloudwatch_log_group.flow_logs.name
}

# --- Alarma ---
output "alarm_name" {
  description = "Nombre de la alarma de tráfico rechazado"
  value       = aws_cloudwatch_metric_alarm.rejected_data.alarm_name
}