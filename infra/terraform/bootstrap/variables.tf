variable "aws_region" {
  description = "AWS region for the bootstrap resources."
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile used by the provider. Null uses the default credential chain."
  type        = string
  default     = null
}

variable "github_repository" {
  description = "GitHub repository (owner/name) allowed to assume the deploy role from the main branch."
  type        = string
  default     = "hiepnguyen06/bidnow-monorepo"
}

variable "budget_email" {
  description = "Email address that receives AWS Budgets alerts."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget in USD."
  type        = number
  default     = 30
}
