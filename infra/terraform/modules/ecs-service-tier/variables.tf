variable "services" {
  description = <<-EOT
    The services of this tier, keyed by service name. Each value holds the inputs of the ecs-service
    module. Extra attributes on the objects passed in are ignored, so the caller can hand over its own
    richer service objects unchanged.
  EOT
  type = map(object({
    port                   = number
    cpu                    = number
    memory                 = number
    image                  = string
    desired_count          = number
    min_count              = number
    max_count              = number
    cluster_name           = string
    cluster_arn            = string
    namespace_arn          = string
    execution_role_arn     = string
    subnet_ids             = list(string)
    security_group_ids     = list(string)
    target_group_arn       = optional(string)
    env                    = map(string)
    secrets                = map(string)
    init_database          = optional(string)
    db_host                = optional(string)
    db_user                = optional(string)
    db_password_secret_arn = optional(string)
    task_policy_json       = optional(string)
  }))
}

variable "aws_region" {
  description = "Region used for the awslogs driver."
  type        = string
}

variable "wait_for_steady_state" {
  description = "Wait until every service of this tier is running before the tier counts as created. Set it for tiers whose services are called by later tiers."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
