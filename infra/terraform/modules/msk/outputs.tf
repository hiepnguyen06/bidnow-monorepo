output "bootstrap_brokers_tls" {
  description = "Comma-separated TLS bootstrap broker list (host:9094)."
  value       = aws_msk_cluster.this.bootstrap_brokers_tls
}

output "cluster_arn" {
  description = "ARN of the MSK cluster."
  value       = aws_msk_cluster.this.arn
}

output "security_group_id" {
  description = "Security group attached to the brokers."
  value       = aws_security_group.this.id
}
