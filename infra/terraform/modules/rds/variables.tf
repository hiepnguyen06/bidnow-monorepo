variable "name" {
  description = "Name prefix applied to every resource."
  type        = string
}

variable "vpc_id" {
  description = "VPC the security group is created in."
  type        = string
}

variable "subnet_ids" {
  description = "Data-tier subnet ids."
  type        = list(string)
}

variable "allowed_sg_ids" {
  description = "Security groups allowed to reach the service port (callers pass the app security group)."
  type        = list(string)
}

variable "multi_az" {
  description = "Run the instance as Multi-AZ."
  type        = bool
  default     = false
}

variable "master_password" {
  description = "Master user password."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
