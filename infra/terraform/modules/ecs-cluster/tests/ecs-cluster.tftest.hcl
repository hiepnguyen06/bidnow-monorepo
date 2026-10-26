mock_provider "aws" {}

variables {
  name = "bidnow-test"
  secret_arns = [
    "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:bidnow-test/db-AbCdEf",
    "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:bidnow-test/jwt-GhIjKl",
  ]
}

run "execution_role_reads_only_given_secrets" {
  command = plan

  assert {
    condition = length([
      for s in jsondecode(aws_iam_role_policy.execution_secrets.policy).Statement : s
      if s.Effect == "Allow" && s.Action == "secretsmanager:GetSecretValue"
    ]) == length(jsondecode(aws_iam_role_policy.execution_secrets.policy).Statement)
    error_message = "Every statement must be an Allow for secretsmanager:GetSecretValue only."
  }

  assert {
    condition     = length(jsondecode(aws_iam_role_policy.execution_secrets.policy).Statement) == 1 && toset(jsondecode(aws_iam_role_policy.execution_secrets.policy).Statement[0].Resource) == toset(var.secret_arns)
    error_message = "The statement must be scoped to exactly the given secret ARNs."
  }

  assert {
    condition     = !contains(jsondecode(aws_iam_role_policy.execution_secrets.policy).Statement[0].Resource, "*")
    error_message = "No wildcard resource is allowed."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.execution_managed.policy_arn == "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
    error_message = "The AWS-managed task execution policy must be attached."
  }

  assert {
    condition     = jsondecode(aws_iam_role.execution.assume_role_policy).Statement[0].Principal.Service == "ecs-tasks.amazonaws.com"
    error_message = "Execution role must be assumable by ecs-tasks."
  }
}

run "namespace_is_bidnow_local" {
  command = plan

  assert {
    condition     = aws_service_discovery_http_namespace.this.name == "bidnow.local"
    error_message = "Service Connect namespace must be bidnow.local."
  }
}

run "container_insights_disabled" {
  command = plan

  assert {
    condition     = aws_ecs_cluster.this.name == "bidnow-test"
    error_message = "Cluster name must equal var.name."
  }

  assert {
    condition     = length([for s in aws_ecs_cluster.this.setting : s if s.name == "containerInsights" && s.value == "disabled"]) == 1
    error_message = "containerInsights must be disabled."
  }
}
