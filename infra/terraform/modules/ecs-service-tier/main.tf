# One tier of services, created together. ECS Service Connect only gives a task the names of the
# services that already exist in the namespace when the task starts. A module cannot order the
# instances of its own for_each, so the caller creates the services in tiers: one instance of this
# module per tier, each with `depends_on` the previous tier. That way servers exist (and, with
# wait_for_steady_state, are running) before the clients that call them start.
module "service" {
  source   = "../ecs-service"
  for_each = var.services

  name       = each.key
  aws_region = var.aws_region

  cluster_name       = each.value.cluster_name
  cluster_arn        = each.value.cluster_arn
  namespace_arn      = each.value.namespace_arn
  execution_role_arn = each.value.execution_role_arn

  image  = each.value.image
  port   = each.value.port
  cpu    = each.value.cpu
  memory = each.value.memory

  desired_count = each.value.desired_count
  min_count     = each.value.min_count
  max_count     = each.value.max_count

  subnet_ids         = each.value.subnet_ids
  security_group_ids = each.value.security_group_ids
  target_group_arn   = each.value.target_group_arn

  env     = each.value.env
  secrets = each.value.secrets

  init_database          = each.value.init_database
  db_host                = each.value.db_host
  db_user                = each.value.db_user
  db_password_secret_arn = each.value.db_password_secret_arn

  task_policy_json = each.value.task_policy_json

  wait_for_steady_state = var.wait_for_steady_state
  tags                  = var.tags
}
