mock_provider "aws" {
  # The provider validates ARN syntax, and the mock would otherwise return a random string.
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/bidnow-test-task"
    }
  }
}

variables {
  aws_region = "ap-southeast-2"

  services = {
    "user-service" = {
      port                   = 8082
      cpu                    = 512
      memory                 = 1024
      image                  = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/user-service:latest"
      desired_count          = 1
      min_count              = 1
      max_count              = 2
      cluster_name           = "bidnow-test"
      cluster_arn            = "arn:aws:ecs:ap-southeast-2:123456789012:cluster/bidnow-test"
      namespace_arn          = "arn:aws:servicediscovery:ap-southeast-2:123456789012:namespace/ns-abcdefghijklmnop"
      execution_role_arn     = "arn:aws:iam::123456789012:role/bidnow-test-exec"
      subnet_ids             = ["subnet-aaaa1111", "subnet-bbbb2222"]
      security_group_ids     = ["sg-0123456789abcdef0"]
      env                    = { DB_USERNAME = "bidnow" }
      secrets                = { DB_PASSWORD = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:bidnow-test/db-AbCdEf" }
      init_database          = "user_db"
      db_host                = "db.example.internal"
      db_user                = "bidnow"
      db_password_secret_arn = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:bidnow-test/db-AbCdEf"
      # Not part of the wrapper's type: envs/demo passes its richer service objects straight through,
      # so extra attributes must be ignored, not rejected.
      database = "user_db"
    }
    "wallet-service" = {
      port               = 8085
      cpu                = 512
      memory             = 1024
      image              = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/wallet-service:latest"
      desired_count      = 1
      min_count          = 1
      max_count          = 2
      cluster_name       = "bidnow-test"
      cluster_arn        = "arn:aws:ecs:ap-southeast-2:123456789012:cluster/bidnow-test"
      namespace_arn      = "arn:aws:servicediscovery:ap-southeast-2:123456789012:namespace/ns-abcdefghijklmnop"
      execution_role_arn = "arn:aws:iam::123456789012:role/bidnow-test-exec"
      subnet_ids         = ["subnet-aaaa1111", "subnet-bbbb2222"]
      security_group_ids = ["sg-0123456789abcdef0"]
      env                = {}
      secrets            = {}
    }
  }
}

run "creates_one_service_per_entry_named_after_its_key" {
  command = apply

  assert {
    condition     = toset(keys(output.service_names)) == toset(["user-service", "wallet-service"])
    error_message = "One ECS service per entry of var.services."
  }

  assert {
    condition     = alltrue([for k, v in output.service_names : v == k])
    error_message = "Each ECS service is named after its key (the Service Connect DNS name)."
  }

  assert {
    condition     = toset(keys(output.task_role_arns)) == toset(["user-service", "wallet-service"])
    error_message = "A task role ARN is exposed for every service."
  }
}

run "an_empty_tier_creates_nothing" {
  command = apply

  variables {
    services = {}
  }

  assert {
    condition     = length(output.service_names) == 0
    error_message = "An empty tier must create no services."
  }
}
