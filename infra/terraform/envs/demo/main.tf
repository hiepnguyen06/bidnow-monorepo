locals {
  # The cluster MUST be named bidnow-demo: the bootstrap GitHub deploy role is scoped to it.
  name = "bidnow-demo"
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------------------
# Network and data tier
# ---------------------------------------------------------------------------

module "network" {
  source = "../../modules/network"

  name     = local.name
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)
  multi_az = var.multi_az
}

module "secrets" {
  source = "../../modules/secrets"

  name = local.name
  mail = var.mail
}

module "rds" {
  source = "../../modules/rds"

  name            = local.name
  vpc_id          = module.network.vpc_id
  subnet_ids      = module.network.data_subnet_ids
  allowed_sg_ids  = [module.network.app_sg_id]
  multi_az        = var.multi_az
  master_password = module.secrets.db_password_value
}

module "elasticache" {
  source = "../../modules/elasticache"

  name           = local.name
  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.data_subnet_ids
  allowed_sg_ids = [module.network.app_sg_id]
}

module "msk" {
  source = "../../modules/msk"

  name   = local.name
  vpc_id = module.network.vpc_id
  # Exactly two data subnets: one broker per subnet.
  subnet_ids     = module.network.data_subnet_ids
  allowed_sg_ids = [module.network.app_sg_id]
}

module "s3_media" {
  source = "../../modules/s3-media"

  name = local.name
}

# ---------------------------------------------------------------------------
# Presentation tier
# ---------------------------------------------------------------------------

module "alb" {
  source = "../../modules/alb"

  name                = local.name
  vpc_id              = module.network.vpc_id
  public_subnet_ids   = module.network.public_subnet_ids
  alb_sg_id           = module.network.alb_sg_id
  origin_verify_value = module.secrets.origin_verify_value
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  name                              = local.name
  alb_dns_name                      = module.alb.dns_name
  origin_verify_value               = module.secrets.origin_verify_value
  media_bucket_id                   = module.s3_media.bucket_id
  media_bucket_arn                  = module.s3_media.bucket_arn
  media_bucket_regional_domain_name = module.s3_media.bucket_regional_domain_name
}

# ---------------------------------------------------------------------------
# Application tier
# ---------------------------------------------------------------------------

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  name        = local.name
  secret_arns = values(module.secrets.secret_arns)
}

# Fail fast (Review Focus 5): a first apply against empty ECR repositories would otherwise
# create the whole stack and leave ECS services retrying image pulls forever.
# repository_name / registry_id are parsed from <account>.dkr.ecr.<region>.amazonaws.com/<name>.
# Keyed by local.service_names (not local.services) so the lookup depends on variables only and
# is read during plan; depending on resources would defer it to apply time.
data "aws_ecr_images" "this" {
  for_each = toset(local.service_names)

  registry_id     = split(".", var.ecr_repository_urls[each.key])[0]
  repository_name = regex("^[^/]+/(.+)$", var.ecr_repository_urls[each.key])[0]
}

resource "terraform_data" "ecr_images_pushed" {
  input = var.image_tag

  lifecycle {
    precondition {
      condition = alltrue([
        for k, d in data.aws_ecr_images.this : contains([for i in d.image_ids : i.image_tag if i.image_tag != null], var.image_tag)
      ])
      error_message = "Push images first: see docs/deployment-aws.md (image tag \"${var.image_tag}\" is missing from: ${join(", ", sort([for k, d in data.aws_ecr_images.this : k if !contains([for i in d.image_ids : i.image_tag if i.image_tag != null], var.image_tag)]))})."
    }
  }
}

module "ecs_service" {
  source   = "../../modules/ecs-service"
  for_each = local.services

  name               = each.key
  aws_region         = var.aws_region
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

  # module.alb: a target group must be attached to the listener (rules) before an ECS service uses it.
  depends_on = [terraform_data.ecr_images_pushed, module.alb]
}
