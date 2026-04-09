# --- Security Group: Bastion (capa pública) ---
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-sg-bastion"
  description = "Allow SSH only from my IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg-bastion"
  })
}

# --- Security Group: App (capa privada de aplicación) ---
resource "aws_security_group" "app" {
  name        = "${var.project_name}-sg-app"
  description = "Allow SSH only from bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg-app"
  })
}

# --- Security Group: Data (capa privada de datos) ---
resource "aws_security_group" "data" {
  name        = "${var.project_name}-sg-data"
  description = "Allow port 5432 only from app layer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Simulated DB port from app layer"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg-data"
  })
}