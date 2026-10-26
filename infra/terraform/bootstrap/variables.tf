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

variable "github_sub_claim_prefix" {
  description = <<-EOT
    Prefix of the `sub` claim in GitHub's OIDC tokens for this repository, everything before ":ref:refs/heads/main".
    Null uses the classic form "repo:<github_repository>". Repositories that use GitHub's immutable subject claim
    (check with `gh api repos/<owner>/<repo>/actions/oidc/customization/sub`: "use_immutable_subject": true) get
    "repo:<owner>@<owner-id>/<repo>@<repo-id>" instead; pass the `sub_claim_prefix` value from that API response.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.github_sub_claim_prefix == null ? true : can(regex("^repo:[^*]+$", var.github_sub_claim_prefix))
    error_message = "github_sub_claim_prefix must start with \"repo:\" and must not contain wildcards."
  }
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
