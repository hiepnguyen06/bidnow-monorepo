locals {
  tags = var.tags

  ecs_tasks_assume = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  execution_secrets_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = var.secret_arns
    }]
  })
}

resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = merge(local.tags, { Name = var.name })
}

# Service Connect namespace: services reach each other as <name>:<port>.
resource "aws_service_discovery_http_namespace" "this" {
  name        = "bidnow.local"
  description = "Service Connect namespace for ${var.name}"

  tags = merge(local.tags, { Name = "${var.name}-namespace" })
}

# Shared task execution role: pulls images, writes logs, injects secrets.
resource "aws_iam_role" "execution" {
  name               = "${var.name}-ecs-execution"
  assume_role_policy = local.ecs_tasks_assume

  tags = merge(local.tags, { Name = "${var.name}-ecs-execution" })
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "${var.name}-read-secrets"
  role   = aws_iam_role.execution.id
  policy = local.execution_secrets_policy
}
