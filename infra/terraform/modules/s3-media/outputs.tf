output "bucket_id" {
  description = "Media bucket name."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Media bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name used as the CloudFront origin."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
