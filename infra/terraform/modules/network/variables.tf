variable "name" {
  description = "Name prefix applied to every resource in the network."
  type        = string
}

variable "azs" {
  description = "Exactly two availability zones to spread subnets across."
  type        = list(string)

  validation {
    condition     = length(var.azs) == 2
    error_message = "azs must contain exactly two availability zones."
  }
}

variable "multi_az" {
  description = "When true, run one NAT gateway per AZ; otherwise a single shared NAT gateway."
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC. Subnet layout assumes the default 10.0.0.0/16."
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
