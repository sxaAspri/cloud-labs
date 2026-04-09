# S3 bucket — almacena los reportes de ataques
resource "aws_s3_bucket" "honeypot_reports" {
  bucket        = "honeypot-reports-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name    = "honeypot-reports"
    Project = "honeypot-aws"
  }
}

# Bloquear acceso público al bucket
resource "aws_s3_bucket_public_access_block" "honeypot_reports" {
  bucket = aws_s3_bucket.honeypot_reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Data source — Account ID
data "aws_caller_identity" "current" {}

# Output
output "reports_bucket" {
  value       = aws_s3_bucket.honeypot_reports.bucket
  description = "Nombre del bucket de reportes"
}
