# Crea una AMI limpia desde la instancia — este es nuestro punto de recuperación
resource "aws_ami_from_instance" "lab_ami" {
  name               = "self-healing-clean-ami"
  source_instance_id = aws_instance.lab_instance.id

  tags = {
    Name    = "self-healing-clean-ami"
    Project = "self-healing-aws"
  }
}

# Output — muestra el ID de la AMI al terminar
output "ami_id" {
  value       = aws_ami_from_instance.lab_ami.id
  description = "ID de la AMI limpia"
}
