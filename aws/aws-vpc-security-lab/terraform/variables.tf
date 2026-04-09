variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for tagging and naming resources"
  type        = string
  default     = "vpc-security-lab"
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "lab"
}

variable "my_ip" {
  description = "Your public IP in CIDR notation for SSH access to bastion"
  type        = string
  default     = "186.30.37.36/32"
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}