# SNS — canal de notificaciones
resource "aws_sns_topic" "honeypot_alerts" {
  name = "honeypot-alerts"

  tags = {
    Project = "honeypot-aws"
  }
}

# Suscripción email
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.honeypot_alerts.arn
  protocol  = "email"
  endpoint  = "UR_EMAIL_AQUI"
}

# Rol IAM para la Lambda
resource "aws_iam_role" "lambda_role" {
  name = "honeypot-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Project = "honeypot-aws"
  }
}

# Permisos de la Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "honeypot-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.honeypot_reports.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.honeypot_alerts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# Empaquetar Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/analyzer.py"
  output_path = "${path.module}/../lambda/analyzer.zip"
}

# Lambda function
resource "aws_lambda_function" "honeypot_analyzer" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "honeypot-analyzer"
  role             = aws_iam_role.lambda_role.arn
  handler          = "analyzer.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      BUCKET_NAME       = aws_s3_bucket.honeypot_reports.bucket
      SNS_TOPIC_ARN     = aws_sns_topic.honeypot_alerts.arn
      SECURITY_GROUP_ID = aws_security_group.honeypot_sg.id
    }
  }

  tags = {
    Name    = "honeypot-analyzer"
    Project = "honeypot-aws"
  }
}

# Permiso para que CloudWatch Logs invoque la Lambda
resource "aws_lambda_permission" "cloudwatch_invoke" {
  statement_id  = "AllowCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.honeypot_analyzer.function_name
  principal     = "logs.amazonaws.com"
}

# CloudWatch Logs subscription — conecta los logs de Cowrie con la Lambda
resource "aws_cloudwatch_log_subscription_filter" "cowrie_filter" {
  name            = "honeypot-cowrie-filter"
  log_group_name  = "/honeypot/cowrie"
  filter_pattern  = ""
  destination_arn = aws_lambda_function.honeypot_analyzer.arn
  depends_on      = [aws_lambda_permission.cloudwatch_invoke]
}

# Outputs
output "lambda_name" {
  value = aws_lambda_function.honeypot_analyzer.function_name
}

output "sns_topic_arn" {
  value = aws_sns_topic.honeypot_alerts.arn
}
