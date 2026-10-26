variable "name" {
  description = "Name prefix applied to every resource in the ALB tier."
  type        = string
}

variable "vpc_id" {
  description = "VPC that hosts the target groups."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets the internet-facing ALB is attached to."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group attached to the ALB."
  type        = string
}

variable "origin_verify_value" {
  description = "Secret value CloudFront sends in the X-Origin-Verify header; requests without it get a 403."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
