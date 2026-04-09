# --- AMI más reciente de Amazon Linux 2023 ---
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- EC2 Bastion (capa publica) ---
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = "vpc-security-lab-key"
  associate_public_ip_address = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-bastion"
    Role = "bastion"
  })
}

# --- EC2 App (capa privada de aplicacion) ---
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.app_a.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = "vpc-security-lab-key"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-app"
    Role = "app"
  })
}

# --- EC2 Data (capa privada de datos, simula DB en puerto 5432) ---
resource "aws_instance" "data" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.data_a.id
  vpc_security_group_ids = [aws_security_group.data.id]
  key_name               = "vpc-security-lab-key"

  user_data = <<-EOF
    #!/bin/bash
    python3 -c "
    import socket
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(('0.0.0.0', 5432))
    s.listen(5)
    while True:
        conn, addr = s.accept()
        conn.send(b'DB simulation running\n')
        conn.close()
    " &
  EOF

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-data"
    Role = "data"
  })
}