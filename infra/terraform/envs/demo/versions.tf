terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # The modules accept >= 5.82; this root needs >= 6.5 for data.aws_ecr_images, which lets
      # the "push images first" precondition give a clear message instead of a native lookup error.
      version = ">= 6.5, < 7"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6, < 4"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "bidnow"
      Environment = "demo"
      ManagedBy   = "terraform"
    }
  }
}
