# Rol IAM — permisos que tiene la Lambda para actuar
resource "aws_iam_role" "lambda_role" {
  name = "self-healing-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Project = "self-healing-aws"
  }
}

# Política — qué acciones puede hacer la Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "self-healing-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances",
          "ec2:RunInstances",
          "ec2:DescribeInstances",
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.security_alerts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Empaqueta el handler.py en un zip para subirlo a AWS
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/handler.py"
  output_path = "${path.module}/../lambda/handler.zip"
}

# Lambda — la función en sí
resource "aws_lambda_function" "security_response" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "self-healing-response"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
      CLEAN_AMI_ID  = aws_ami_from_instance.lab_ami.id
    }
  }

  tags = {
    Name    = "self-healing-response"
    Project = "self-healing-aws"
  }
}

# EventBridge rule — escucha findings de GuardDuty severity >= 7
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "self-healing-guardduty-rule"
  description = "Captura findings de GuardDuty con severidad alta"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })

  tags = {
    Project = "self-healing-aws"
  }
}

# Conecta EventBridge con la Lambda
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "self-healing-lambda"
  arn       = aws_lambda_function.security_response.arn
}

# Permiso para que EventBridge pueda invocar la Lambda
resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.security_response.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_findings.arn
}

# Output
output "lambda_function_name" {
  value       = aws_lambda_function.security_response.function_name
  description = "Nombre de la Lambda"
}
