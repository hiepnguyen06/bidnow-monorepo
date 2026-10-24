output "secret_arns" {
  description = "Secret ARNs keyed by db_password, jwt_secret, mail_host, mail_port, mail_username, mail_password, mail_from."
  value       = { for k, s in aws_secretsmanager_secret.this : k => s.arn }
}

output "db_password_value" {
  description = "Generated RDS master password."
  value       = random_password.db.result
  sensitive   = true
}

output "origin_verify_value" {
  description = "Generated CloudFront to ALB origin-verify header value."
  value       = random_password.origin_verify.result
  sensitive   = true
}
