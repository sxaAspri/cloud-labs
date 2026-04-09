# Security Group — puertos abiertos para atraer atacantes
resource "aws_security_group" "honeypot_sg" {
  name        = "honeypot-sg"
  description = "Security group del honeypot"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Telnet"
    from_port   = 23
    to_port     = 23
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH admin"
    from_port   = 2222
    to_port     = 2222
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
    Name    = "honeypot-sg"
    Project = "honeypot-aws"
  }
}

# EC2 — Amazon Linux 2023 con Python 3.11
resource "aws_instance" "honeypot" {
  ami                    = "ami-0ea87431b78a82070" # Amazon Linux 2023 us-east-1
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.honeypot_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.honeypot_profile.name

  user_data = <<-EOF
    #!/bin/bash
    set -e
    exec > /var/log/cowrie-install.log 2>&1

    echo "=== Iniciando instalación de Cowrie ==="
    dnf update -y
    dnf install -y python3.11 python3.11-pip git libffi-devel openssl-devel

    echo "=== Creando usuario cowrie ==="
    useradd -m cowrie

    echo "=== Clonando Cowrie ==="
    cd /home/cowrie
    git clone https://github.com/cowrie/cowrie.git
    cd cowrie

    echo "=== Instalando dependencias ==="
    python3.11 -m venv cowrie-env
    source cowrie-env/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    pip install -e .

    echo "=== Configurando Cowrie ==="
    cp etc/cowrie.cfg.dist etc/cowrie.cfg
    sed -i 's/hostname = svr04/hostname = production-server/' etc/cowrie.cfg
    sed -i '645s/.*/listen_endpoints = tcp:22:interface=0.0.0.0/' etc/cowrie.cfg

    echo "=== Permisos para puerto 22 ==="
    setcap cap_net_bind_service=+ep /usr/bin/python3.11

    echo "=== Moviendo SSH real al puerto 2222 ==="
    sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
    systemctl restart sshd

    echo "=== Ajustando permisos ==="
    chown -R cowrie:cowrie /home/cowrie/cowrie

    echo "=== Instalando CloudWatch Agent ==="
    dnf install -y amazon-cloudwatch-agent

    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWCONFIG'
    {
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/home/cowrie/cowrie/var/log/cowrie/cowrie.json",
                "log_group_name": "/honeypot/cowrie",
                "log_stream_name": "{instance_id}",
                "timezone": "UTC"
              }
            ]
          }
        }
      }
    }
    CWCONFIG

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

    echo "=== Arrancando Cowrie ==="
    su - cowrie -c "cd /home/cowrie/cowrie && source cowrie-env/bin/activate && bin/regen-dropin.cache && cowrie-env/bin/cowrie start"

    echo "=== Instalación completada ==="
  EOF

  tags = {
    Name    = "honeypot-server"
    Project = "honeypot-aws"
  }
}

output "honeypot_ip" {
  value       = aws_instance.honeypot.public_ip
  description = "IP pública del honeypot"
}

output "honeypot_id" {
  value       = aws_instance.honeypot.id
  description = "ID de la instancia honeypot"
}
