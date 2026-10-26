variable "name" {
  description = "Name prefix applied to every resource in the CloudFront tier."
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the public ALB used as the dynamic origin."
  type        = string
}

variable "origin_verify_value" {
  description = "Secret value sent to the ALB in the X-Origin-Verify header on every origin request."
  type        = string
  sensitive   = true
}

variable "media_bucket_id" {
  description = "Id (name) of the private media bucket that receives the bucket policy and CORS configuration."
  type        = string
}

variable "media_bucket_arn" {
  description = "ARN of the private media bucket."
  type        = string
}

variable "media_bucket_regional_domain_name" {
  description = "Regional domain name of the media bucket, used as the S3 origin."
  type        = string
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
