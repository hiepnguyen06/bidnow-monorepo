terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.82, < 7"
    }
  }

  # Local backend on purpose: this stack creates the state bucket, so it cannot
  # store its own state there. The terraform.tfstate file is kept by the owner
  # (it is git-ignored). Back it up; this stack is applied once and never destroyed.
  backend "local" {}
}
