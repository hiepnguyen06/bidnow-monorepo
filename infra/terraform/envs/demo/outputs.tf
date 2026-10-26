output "cloudfront_url" {
  description = "Public URL of the app (the hostname changes on every fresh apply)."
  value       = local.public_url
}

output "alb_dns_name" {
  description = "ALB DNS name; direct requests get 403 (no X-Origin-Verify header)."
  value       = module.alb.dns_name
}

output "cluster_name" {
  description = "ECS cluster name used by the deploy workflow."
  value       = module.ecs_cluster.cluster_name
}

output "rds_address" {
  description = "RDS PostgreSQL endpoint hostname (private)."
  value       = module.rds.address
}

output "msk_bootstrap_brokers_tls" {
  description = "MSK TLS bootstrap brokers (private)."
  value       = module.msk.bootstrap_brokers_tls
}

output "media_bucket" {
  description = "Name of the private media bucket."
  value       = module.s3_media.bucket_id
}
