output "domain_name" {
  description = "The *.cloudfront.net hostname of the distribution."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_arn" {
  description = "ARN of the distribution."
  value       = aws_cloudfront_distribution.this.arn
}
