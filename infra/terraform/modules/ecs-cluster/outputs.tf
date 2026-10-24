output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

output "namespace_arn" {
  description = "ARN of the Service Connect namespace (bidnow.local)."
  value       = aws_service_discovery_http_namespace.this.arn
}

output "execution_role_arn" {
  description = "ARN of the shared task execution role."
  value       = aws_iam_role.execution.arn

  # Consumers must not start tasks before the role has its permissions.
  depends_on = [
    aws_iam_role_policy_attachment.execution_managed,
    aws_iam_role_policy.execution_secrets,
  ]
}
