mock_provider "aws" {}

variables {
  name               = "bidding"
  cluster_arn        = "arn:aws:ecs:ap-southeast-2:123456789012:cluster/bidnow-test"
  cluster_name       = "bidnow-test"
  namespace_arn      = "arn:aws:servicediscovery:ap-southeast-2:123456789012:namespace/ns-abcdefghijklmnop"
  execution_role_arn = "arn:aws:iam::123456789012:role/bidnow-test-exec"
  aws_region         = "ap-southeast-2"
  image              = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/bidding:latest"
  port               = 8083
  subnet_ids         = ["subnet-aaaa1111", "subnet-bbbb2222"]
  security_group_ids = ["sg-0123456789abcdef0"]
  env = {
    SPRING_PROFILES_ACTIVE = "aws"
    DB_PORT                = "5432"
  }
  secrets = {
    JWT_SECRET  = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:bidnow-test/jwt-GhIjKl"
    DB_PASSWORD = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:bidnow-test/db-AbCdEf"
  }
}

run "init_container_present_only_when_database_set" {
  command = plan

  assert {
    condition     = length(jsondecode(aws_ecs_task_definition.this.container_definitions)) == 1 && jsondecode(aws_ecs_task_definition.this.container_definitions)[0].name == "bidding"
    error_message = "Without init_database only the main container must exist."
  }
}

run "init_container_defined_when_database_set" {
  command = plan

  variables {
    init_database          = "bidding_db"
    db_host                = "db.example.internal"
    db_user                = "bidnow"
    db_password_secret_arn = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:bidnow-test/db-AbCdEf"
  }

  assert {
    condition     = length(jsondecode(aws_ecs_task_definition.this.container_definitions)) == 2
    error_message = "With init_database two containers are expected."
  }

  assert {
    condition = length([
      for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c
      if c.name == "db-init" && c.image == "postgres:15-alpine" && c.essential == false
    ]) == 1
    error_message = "db-init must be a non-essential postgres:15-alpine container."
  }

  assert {
    condition = (
      toset([for e in one([for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c if c.name == "db-init"]).environment : e.name]) == toset(["PGHOST", "PGUSER", "DB_NAME"]) &&
      [for s in one([for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c if c.name == "db-init"]).secrets : s.name] == ["PGPASSWORD"] &&
      [for s in one([for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c if c.name == "db-init"]).secrets : s.valueFrom] == [var.db_password_secret_arn]
    )
    error_message = "db-init gets PGHOST/PGUSER/DB_NAME as env and PGPASSWORD as a secret from the given ARN."
  }

  assert {
    condition = (
      one([for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c if c.name == "db-init"]).logConfiguration.options["awslogs-group"] == "/ecs/bidding" &&
      one([for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c if c.name == "db-init"]).logConfiguration.options["awslogs-stream-prefix"] != one([for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c if c.name == "bidding"]).logConfiguration.options["awslogs-stream-prefix"]
    )
    error_message = "db-init logs to the shared group with its own stream prefix."
  }

  assert {
    condition = (
      length(regexall("CREATE DATABASE", join(" ", one([for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c if c.name == "db-init"]).command))) > 0 &&
      length(regexall("pg_database", join(" ", one([for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c if c.name == "db-init"]).command))) > 0 &&
      length(regexall("bidding_db", join(" ", one([for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c if c.name == "db-init"]).command))) == 0
    )
    error_message = "db-init command is idempotent and reads the database name from the DB_NAME env, not interpolated."
  }

  assert {
    condition     = one([for e in one([for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c if c.name == "db-init"]).environment : e.value if e.name == "DB_NAME"]) == "bidding_db"
    error_message = "DB_NAME must carry the database name."
  }
}

run "main_container_waits_for_init_success" {
  command = plan

  variables {
    init_database          = "bidding_db"
    db_host                = "db.example.internal"
    db_user                = "bidnow"
    db_password_secret_arn = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:bidnow-test/db-AbCdEf"
  }

  assert {
    condition = (
      length(one([for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c if c.name == "bidding"]).dependsOn) == 1 &&
      one([for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c if c.name == "bidding"]).dependsOn[0].containerName == "db-init" &&
      one([for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c if c.name == "bidding"]).dependsOn[0].condition == "SUCCESS"
    )
    error_message = "Main container must depend on db-init with condition SUCCESS."
  }
}

run "main_container_has_no_dependency_without_init" {
  command = plan

  assert {
    condition     = !contains(keys(jsondecode(aws_ecs_task_definition.this.container_definitions)[0]), "dependsOn")
    error_message = "No dependsOn expected without init_database."
  }
}

run "secrets_are_not_plain_env" {
  command = plan

  assert {
    condition = (
      toset([for s in jsondecode(aws_ecs_task_definition.this.container_definitions)[0].secrets : s.name]) == toset(["JWT_SECRET", "DB_PASSWORD"]) &&
      length(setintersection(
        toset([for s in jsondecode(aws_ecs_task_definition.this.container_definitions)[0].secrets : s.name]),
        toset([for e in jsondecode(aws_ecs_task_definition.this.container_definitions)[0].environment : e.name])
      )) == 0
    )
    error_message = "Secrets must be in the secrets list only, never in environment."
  }

  assert {
    condition     = one([for s in jsondecode(aws_ecs_task_definition.this.container_definitions)[0].secrets : s.valueFrom if s.name == "JWT_SECRET"]) == var.secrets["JWT_SECRET"]
    error_message = "Secret valueFrom must be the given ARN."
  }

  assert {
    condition     = [for e in jsondecode(aws_ecs_task_definition.this.container_definitions)[0].environment : e.name] == ["DB_PORT", "SPRING_PROFILES_ACTIVE"]
    error_message = "Plain env must hold exactly the given env vars, sorted by name."
  }
}

run "main_container_basics" {
  command = plan

  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].essential == true && !contains(keys(jsondecode(aws_ecs_task_definition.this.container_definitions)[0]), "healthCheck")
    error_message = "Main container is essential with no container health check."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].portMappings[0].name == "bidding" && jsondecode(aws_ecs_task_definition.this.container_definitions)[0].portMappings[0].containerPort == 8083
    error_message = "Port mapping must be named after the service and use the port."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].logConfiguration.options["awslogs-region"] == "ap-southeast-2" && jsondecode(aws_ecs_task_definition.this.container_definitions)[0].logConfiguration.options["awslogs-group"] == "/ecs/bidding"
    error_message = "awslogs must target /ecs/<name> in the given region."
  }

  assert {
    condition     = aws_cloudwatch_log_group.this.name == "/ecs/bidding" && aws_cloudwatch_log_group.this.retention_in_days == 7
    error_message = "Log group /ecs/<name> with 7 day default retention."
  }
}

run "circuit_breaker_rollback_enabled" {
  command = plan

  assert {
    condition     = aws_ecs_service.this.deployment_circuit_breaker[0].enable == true && aws_ecs_service.this.deployment_circuit_breaker[0].rollback == true
    error_message = "Circuit breaker with rollback must be enabled."
  }

  assert {
    condition     = aws_ecs_service.this.launch_type == "FARGATE" && aws_ecs_service.this.network_configuration[0].assign_public_ip == false && aws_ecs_service.this.wait_for_steady_state == false
    error_message = "Fargate, private IPs, no waiting for steady state."
  }
}

run "autoscaling_target_is_cpu_60" {
  command = plan

  assert {
    condition     = aws_appautoscaling_target.this.service_namespace == "ecs" && aws_appautoscaling_target.this.scalable_dimension == "ecs:service:DesiredCount" && aws_appautoscaling_target.this.resource_id == "service/bidnow-test/bidding"
    error_message = "Autoscaling target must address service/<cluster>/<name> DesiredCount."
  }

  assert {
    condition     = aws_appautoscaling_target.this.min_capacity == 1 && aws_appautoscaling_target.this.max_capacity == 2
    error_message = "Default scaling range is 1..2."
  }

  assert {
    condition     = aws_appautoscaling_policy.cpu.policy_type == "TargetTrackingScaling" && aws_appautoscaling_policy.cpu.target_tracking_scaling_policy_configuration[0].target_value == 60 && aws_appautoscaling_policy.cpu.target_tracking_scaling_policy_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ECSServiceAverageCPUUtilization"
    error_message = "Policy must track average CPU at 60."
  }
}

run "platform_is_x86_64" {
  command = plan

  assert {
    condition     = aws_ecs_task_definition.this.runtime_platform[0].cpu_architecture == "X86_64" && aws_ecs_task_definition.this.runtime_platform[0].operating_system_family == "LINUX"
    error_message = "Runtime platform must be X86_64/LINUX."
  }

  assert {
    condition     = aws_ecs_task_definition.this.network_mode == "awsvpc" && contains(aws_ecs_task_definition.this.requires_compatibilities, "FARGATE") && aws_ecs_task_definition.this.cpu == "512" && aws_ecs_task_definition.this.memory == "1024"
    error_message = "Fargate awsvpc with default 512/1024 sizing."
  }
}

run "no_task_policy_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.task) == 0
    error_message = "No inline task policy without task_policy_json."
  }

  assert {
    condition     = jsondecode(aws_iam_role.task.assume_role_policy).Statement[0].Principal.Service == "ecs-tasks.amazonaws.com"
    error_message = "Task role must be assumable by ecs-tasks."
  }
}

run "task_role_has_only_given_policy" {
  command = plan

  variables {
    task_policy_json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::media/*\"}]}"
  }

  assert {
    condition     = length(aws_iam_role_policy.task) == 1 && aws_iam_role_policy.task[0].policy == var.task_policy_json
    error_message = "The given policy must be attached verbatim as the single inline policy."
  }
}

run "service_connect_alias_matches_name_and_port" {
  command = plan

  assert {
    condition     = aws_ecs_service.this.service_connect_configuration[0].enabled == true && aws_ecs_service.this.service_connect_configuration[0].namespace == var.namespace_arn
    error_message = "Service Connect must be enabled in the given namespace."
  }

  assert {
    condition     = one(aws_ecs_service.this.service_connect_configuration[0].service).port_name == "bidding" && one(one(aws_ecs_service.this.service_connect_configuration[0].service).client_alias).dns_name == "bidding" && one(one(aws_ecs_service.this.service_connect_configuration[0].service).client_alias).port == 8083
    error_message = "Client alias must be name:port bound to the named port mapping."
  }
}

# TCP-mode Service Connect: an http appProtocol makes Envoy apply a 15 s per-request timeout and HTTP
# semantics that can cut the raw WebSocket upgrade from api-gateway to media-service.
run "port_mapping_has_no_http_app_protocol" {
  command = plan

  assert {
    condition = alltrue([
      for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : alltrue([
        for p in try(c.portMappings, []) : try(p.appProtocol, null) == null
      ])
    ])
    error_message = "Port mappings must not set appProtocol (Service Connect stays in TCP mode)."
  }

  assert {
    condition = one([
      for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c if c.name == "bidding"
    ]).portMappings == [{ name = "bidding", containerPort = 8083, protocol = "tcp" }]
    error_message = "The main container keeps its named tcp port mapping for Service Connect."
  }
}

run "load_balancer_block_only_when_target_group_given" {
  command = plan

  assert {
    condition     = length(aws_ecs_service.this.load_balancer) == 0 && aws_ecs_service.this.health_check_grace_period_seconds == null
    error_message = "No load balancer and no grace period without target_group_arn."
  }
}

run "load_balancer_block_present_with_target_group" {
  command = plan

  variables {
    target_group_arn = "arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:targetgroup/bidnow-test-gateway/4444444444444444"
  }

  assert {
    condition     = length(aws_ecs_service.this.load_balancer) == 1 && one(aws_ecs_service.this.load_balancer).container_name == "bidding" && one(aws_ecs_service.this.load_balancer).container_port == 8083 && one(aws_ecs_service.this.load_balancer).target_group_arn == var.target_group_arn
    error_message = "Load balancer block must point at the main container and port."
  }

  assert {
    condition     = aws_ecs_service.this.health_check_grace_period_seconds == 120
    error_message = "Grace period 120s with a load balancer."
  }
}

run "invalid_init_database_rejected" {
  command = plan

  variables {
    init_database          = "Bad-Name; DROP"
    db_host                = "db.example.internal"
    db_user                = "bidnow"
    db_password_secret_arn = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:bidnow-test/db-AbCdEf"
  }

  expect_failures = [var.init_database]
}

run "init_database_requires_connection_details" {
  command = plan

  variables {
    init_database = "bidding_db"
  }

  expect_failures = [aws_ecs_task_definition.this]
}
