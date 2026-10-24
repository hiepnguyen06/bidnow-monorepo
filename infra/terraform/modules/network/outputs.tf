output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB, NAT gateways)."
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "Private app subnet IDs (ECS tasks)."
  value       = aws_subnet.app[*].id
}

output "data_subnet_ids" {
  description = "Isolated data subnet IDs (RDS, ElastiCache, MSK)."
  value       = aws_subnet.data[*].id
}

output "alb_sg_id" {
  description = "Security group ID of the ALB."
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "Security group ID shared by the ECS tasks."
  value       = aws_security_group.app.id
}
