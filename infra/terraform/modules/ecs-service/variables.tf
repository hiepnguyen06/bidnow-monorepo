variable "name" {
  description = "Service name; also the container name, the log group suffix and the Service Connect DNS name."
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the ECS cluster."
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster (needed for the autoscaling resource id)."
  type        = string
}

variable "namespace_arn" {
  description = "ARN of the Service Connect namespace."
  type        = string
}

variable "execution_role_arn" {
  description = "ARN of the shared task execution role."
  type        = string
}

variable "aws_region" {
  description = "Region used for the awslogs driver."
  type        = string
}

variable "image" {
  description = "Container image of the main container."
  type        = string
}

variable "port" {
  description = "Container port exposed by the main container."
  type        = number
}

variable "cpu" {
  description = "Task CPU units."
  type        = number
  default     = 512
}

variable "memory" {
  description = "Task memory in MiB."
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Initial desired task count (autoscaling owns it afterwards)."
  type        = number
  default     = 1
}

variable "min_count" {
  description = "Autoscaling minimum task count."
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Autoscaling maximum task count."
  type        = number
  default     = 2
}

variable "subnet_ids" {
  description = "Subnets the tasks run in."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to the tasks."
  type        = list(string)
}

variable "env" {
  description = "Plain environment variables for the main container."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Map of environment variable name to Secrets Manager secret ARN."
  type        = map(string)
  default     = {}
}

variable "target_group_arn" {
  description = "ALB target group to register the main container with. Null for internal-only services."
  type        = string
  default     = null
}

variable "init_database" {
  description = "Database to create (if missing) by a db-init container before the main container starts. Null disables it."
  type        = string
  default     = null

  validation {
    condition     = var.init_database == null || can(regex("^[a-z][a-z0-9_]*$", var.init_database))
    error_message = "init_database must match ^[a-z][a-z0-9_]*$."
  }
}

variable "db_host" {
  description = "Database host for the db-init container. Required when init_database is set."
  type        = string
  default     = null
}

variable "db_user" {
  description = "Database user for the db-init container. Required when init_database is set."
  type        = string
  default     = null
}

variable "db_password_secret_arn" {
  description = "Secret ARN holding the database password for db-init. Required when init_database is set."
  type        = string
  default     = null
}

variable "task_policy_json" {
  description = "Optional IAM policy document attached inline to the task role."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
