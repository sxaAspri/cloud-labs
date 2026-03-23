# Security Group — controla qué tráfico entra y sale
resource "aws_security_group" "lab_sg" {
  name        = "self-healing-lab-sg"
  description = "Security group para el lab"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "self-healing-lab-sg"
    Project = "self-healing-aws"
  }
}

# EC2 — el servidor que vamos a proteger
resource "aws_instance" "lab_instance" {
  ami                    = "ami-0c02fb55956c7d316" # Amazon Linux 2023 us-east-1
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.lab_sg.id]

  tags = {
    Name    = "self-healing-lab"
    Project = "self-healing-aws"
  }
}

# Output — muestra el ID de la instancia al terminar
output "instance_id" {
  value       = aws_instance.lab_instance.id
  description = "ID de la instancia EC2"
}
