variable "aws_region" {
  description = "AWS region of the demo stack."
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile; null uses the default credential chain."
  type        = string
  default     = null
}

variable "multi_az" {
  description = "High-availability switch: second NAT gateway, Multi-AZ RDS and two tasks per service."
  type        = bool
  default     = false
}

variable "image_tag" {
  description = "Image tag deployed for every service (the pipeline pushes the commit SHA and latest)."
  type        = string
  default     = "latest"
}

variable "ecr_repository_urls" {
  description = "ECR repository URL per service, from the bootstrap output ecr_repository_urls."
  type        = map(string)

  validation {
    condition = alltrue([
      for k in ["frontend", "api-gateway", "identity-service", "user-service", "auction-service", "bidding-service", "wallet-service", "media-service"] :
      contains(keys(var.ecr_repository_urls), k)
    ])
    error_message = "ecr_repository_urls must contain frontend, api-gateway, identity-service, user-service, auction-service, bidding-service, wallet-service and media-service."
  }

  validation {
    condition     = alltrue([for u in values(var.ecr_repository_urls) : can(regex("^[0-9]{12}\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/.+$", u))])
    error_message = "Each ECR repository URL must look like <account>.dkr.ecr.<region>.amazonaws.com/<name>."
  }
}

variable "mail" {
  description = "SMTP settings copied from the local .env; stored in Secrets Manager, never in plain env."
  type = object({
    host     = string
    port     = string
    username = string
    password = string
    from     = string
  })
  sensitive = true
}
