output "state_bucket" {
  description = "S3 bucket holding the Terraform state of envs/demo."
  value       = aws_s3_bucket.state.id
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by service name."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "github_deploy_role_arn" {
  description = "IAM role assumed by GitHub Actions through OIDC."
  value       = aws_iam_role.github_deploy.arn
}
