variable "name" {
  description = "Cluster name and name prefix for the cluster-level resources, for example bidnow-demo."
  type        = string
}

variable "secret_arns" {
  description = "ARNs of the Secrets Manager secrets the task execution role may read (exact ARNs, no wildcard)."
  type        = list(string)

  validation {
    condition     = length(var.secret_arns) > 0 && !contains(var.secret_arns, "*")
    error_message = "secret_arns must contain at least one exact secret ARN and no wildcard."
  }
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
