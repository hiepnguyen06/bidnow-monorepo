mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

variables {
  budget_email = "owner@example.com"
}

run "ecr_has_eight_repos_with_lifecycle" {
  command = plan

  assert {
    condition = toset(keys(aws_ecr_repository.this)) == toset([
      "frontend", "api-gateway", "identity-service", "user-service",
      "auction-service", "bidding-service", "wallet-service", "media-service",
    ])
    error_message = "Expected exactly the eight service ECR repositories."
  }

  assert {
    condition     = alltrue([for r in aws_ecr_repository.this : r.image_scanning_configuration[0].scan_on_push])
    error_message = "Every ECR repository must scan on push."
  }

  assert {
    condition     = length(aws_ecr_lifecycle_policy.this) == 8
    error_message = "Every ECR repository needs a lifecycle policy."
  }
}

run "state_bucket_is_versioned_and_private" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "State bucket versioning must be enabled."
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.state.block_public_acls,
      aws_s3_bucket_public_access_block.state.block_public_policy,
      aws_s3_bucket_public_access_block.state.ignore_public_acls,
      aws_s3_bucket_public_access_block.state.restrict_public_buckets,
    ])
    error_message = "State bucket must block all public access."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.state.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    error_message = "State bucket must be encrypted."
  }
}

run "oidc_trust_is_limited_to_main_and_dispatch" {
  command = plan

  assert {
    condition     = contains(aws_iam_openid_connect_provider.github.client_id_list, "sts.amazonaws.com")
    error_message = "OIDC provider must allow the sts.amazonaws.com audience."
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github.url == "https://token.actions.githubusercontent.com"
    error_message = "OIDC provider must be GitHub Actions."
  }

  assert {
    condition     = jsondecode(aws_iam_role.github_deploy.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == ["repo:hiepnguyen06/bidnow-monorepo:ref:refs/heads/main"]
    error_message = "Trust policy sub must be exactly the main ref of the repository."
  }

  assert {
    condition     = jsondecode(aws_iam_role.github_deploy.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com"
    error_message = "Trust policy audience must be sts.amazonaws.com."
  }

  assert {
    condition     = !can(jsondecode(aws_iam_role.github_deploy.assume_role_policy).Statement[0].Condition.StringLike)
    error_message = "Trust policy must not use wildcard (StringLike) conditions."
  }
}

run "budget_has_email_subscriber" {
  command = plan

  assert {
    condition     = contains(flatten([for n in aws_budgets_budget.monthly.notification : n.subscriber_email_addresses]), "owner@example.com")
    error_message = "Budget must notify the owner email."
  }

  assert {
    condition     = aws_budgets_budget.monthly.limit_amount == "30"
    error_message = "Default monthly budget should be 30 USD."
  }
}
