output "service_names" {
  description = "Service name of each ECS service in this tier, keyed by the key in var.services."
  value       = { for k, m in module.service : k => m.service_name }
}

output "task_role_arns" {
  description = "Task role ARN of each service in this tier, keyed by the key in var.services."
  value       = { for k, m in module.service : k => m.task_role_arn }
}
