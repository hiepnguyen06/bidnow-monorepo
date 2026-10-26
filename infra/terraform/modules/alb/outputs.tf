output "dns_name" {
  description = "DNS name of the ALB (CloudFront origin domain)."
  value       = aws_lb.this.dns_name
}

output "arn" {
  description = "ARN of the load balancer."
  value       = aws_lb.this.arn
}

output "arn_suffix" {
  description = "ARN suffix of the load balancer, used in CloudWatch metrics and autoscaling policies."
  value       = aws_lb.this.arn_suffix
}

output "frontend_target_group_arn" {
  description = "ARN of the frontend (port 3000) target group."
  value       = aws_lb_target_group.frontend.arn
}

output "gateway_target_group_arn" {
  description = "ARN of the API gateway (port 8080) target group."
  value       = aws_lb_target_group.gateway.arn
}
