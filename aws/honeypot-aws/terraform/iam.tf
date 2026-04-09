# Rol IAM para la EC2
resource "aws_iam_role" "honeypot_role" {
  name = "honeypot-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Project = "honeypot-aws"
  }
}

# Permiso para escribir en CloudWatch
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.honeypot_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance profile — conecta el rol con la EC2
resource "aws_iam_instance_profile" "honeypot_profile" {
  name = "honeypot-instance-profile"
  role = aws_iam_role.honeypot_role.name
}
