variable "env" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "peer_vpc_id" {
  description = "VPC ID to peer with"
  type        = string
}

variable "peer_cidr_block" {
  description = "CIDR block of the peered VPC"
  type        = string
}

# Output Variables
output "public_ip" {
  value = aws_instance.web.public_ip
}

output "private_ips" {
  value = aws_instance.mysql[*].private_ip
}
