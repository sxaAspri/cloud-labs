# CloudTrail — registra toda la actividad de la cuenta
resource "aws_cloudtrail" "lab_trail" {
  name                          = "self-healing-trail"
  s3_bucket_name                = aws_s3_bucket.trail_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true

  tags = {
    Name    = "self-healing-trail"
    Project = "self-healing-aws"
  }
}

# S3 bucket — CloudTrail necesita un bucket para guardar los logs
resource "aws_s3_bucket" "trail_bucket" {
  bucket        = "self-healing-trail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Project = "self-healing-aws"
  }
}

# Política del bucket — permite que CloudTrail escriba en él
resource "aws_s3_bucket_policy" "trail_bucket_policy" {
  bucket = aws_s3_bucket.trail_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.trail_bucket.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.trail_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# GuardDuty — detecta amenazas automáticamente
resource "aws_guardduty_detector" "lab_detector" {
  enable = true

  tags = {
    Name    = "self-healing-detector"
    Project = "self-healing-aws"
  }
}

# Data source — obtiene el Account ID automáticamente
data "aws_caller_identity" "current" {}
