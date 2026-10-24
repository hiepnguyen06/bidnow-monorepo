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

  log_options = {
    "awslogs-group"  = "/ecs/${var.name}"
    "awslogs-region" = var.aws_region
  }

  # The database name reaches the shell only through the DB_NAME environment variable
  # (validated against ^[a-z][a-z0-9_]*$) and psql quotes it as an identifier via format(%I).
  db_init_script = join("\n", [
    "set -eu",
    "psql -v ON_ERROR_STOP=1 -v db=\"$DB_NAME\" -d postgres <<'SQL'",
    "SELECT format('CREATE DATABASE %I', :'db') WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db')\\gexec",
    "SQL",
  ])

  db_init_container = {
    name      = "db-init"
    image     = "postgres:15-alpine"
    essential = false
    command   = ["sh", "-c", local.db_init_script]
    environment = [
      { name = "DB_NAME", value = coalesce(var.init_database, "unset") },
      { name = "PGHOST", value = coalesce(var.db_host, "unset") },
      { name = "PGUSER", value = coalesce(var.db_user, "unset") },
    ]
    secrets = [
      { name = "PGPASSWORD", valueFrom = coalesce(var.db_password_secret_arn, "unset") },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options   = merge(local.log_options, { "awslogs-stream-prefix" = "db-init" })
    }
  }

  main_container = merge(
    {
      name      = var.name
      image     = var.image
      essential = true
      portMappings = [
        {
          name          = var.name
          containerPort = var.port
          protocol      = "tcp"
          appProtocol   = "http"
        },
      ]
      environment = [for k in sort(keys(var.env)) : { name = k, value = var.env[k] }]
      secrets     = [for k in sort(keys(var.secrets)) : { name = k, valueFrom = var.secrets[k] }]
      logConfiguration = {
        logDriver = "awslogs"
        options   = merge(local.log_options, { "awslogs-stream-prefix" = var.name })
      }
    },
    var.init_database == null ? {} : {
      dependsOn = [{ containerName = "db-init", condition = "SUCCESS" }]
    },
  )

  container_definitions = concat(var.init_database == null ? [] : [local.db_init_container], [local.main_container])
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days

  tags = merge(local.tags, { Name = "${var.name}-logs" })
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = local.ecs_tasks_assume

  tags = merge(local.tags, { Name = "${var.name}-task" })
}

resource "aws_iam_role_policy" "task" {
  count = var.task_policy_json == null ? 0 : 1

  name   = "${var.name}-task"
  role   = aws_iam_role.task.id
  policy = var.task_policy_json
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = aws_iam_role.task.arn
  container_definitions    = jsonencode(local.container_definitions)

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  lifecycle {
    precondition {
      condition     = var.init_database == null || (var.db_host != null && var.db_user != null && var.db_password_secret_arn != null)
      error_message = "init_database requires db_host, db_user and db_password_secret_arn."
    }
  }

  tags = merge(local.tags, { Name = var.name })
}

resource "aws_ecs_service" "this" {
  name                   = var.name
  cluster                = var.cluster_arn
  task_definition        = aws_ecs_task_definition.this.arn
  launch_type            = "FARGATE"
  desired_count          = var.desired_count
  wait_for_steady_state  = false
  enable_execute_command = false

  health_check_grace_period_seconds = var.target_group_arn == null ? null : 120

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.namespace_arn

    service {
      port_name = var.name

      client_alias {
        port     = var.port
        dns_name = var.name
      }
    }
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn == null ? [] : [var.target_group_arn]

    content {
      target_group_arn = load_balancer.value
      container_name   = var.name
      container_port   = var.port
    }
  }

  lifecycle {
    # Autoscaling owns the running count.
    ignore_changes = [desired_count]
  }

  tags = merge(local.tags, { Name = var.name })
}

resource "aws_appautoscaling_target" "this" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${var.cluster_name}/${var.name}"
  min_capacity       = var.min_count
  max_capacity       = var.max_count

  depends_on = [aws_ecs_service.this]
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  resource_id        = aws_appautoscaling_target.this.resource_id

  target_tracking_scaling_policy_configuration {
    target_value = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
