terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.82, < 7"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6, < 4"
    }
  }
}
