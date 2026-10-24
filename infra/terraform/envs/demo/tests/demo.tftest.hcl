# Offline tests: every provider is mocked, nothing reaches AWS.
# Computed attributes that the wiring depends on are overridden with recognisable values so the
# assertions prove the value flowed from the right module (not just "something is set").

mock_provider "random" {}

mock_provider "aws" {
  # The provider validates ARN-typed arguments during a mocked apply, so resources whose ARN
  # feeds another resource get well-formed defaults.
  mock_resource "aws_lb" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:loadbalancer/app/bidnow-demo-alb/50dc6c495c0c9188"
    }
  }

  mock_resource "aws_lb_listener" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:listener/app/bidnow-demo-alb/50dc6c495c0c9188/f2f7dc8efc522ab2"
    }
  }

  # Default for the per-service task roles; the shared execution role is overridden below with a
  # distinct ARN so the wiring assertion can tell them apart.
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/bidnow-demo-task"
    }
  }

  override_resource {
    target = module.ecs_cluster.aws_iam_role.execution
    values = {
      arn = "arn:aws:iam::123456789012:role/bidnow-demo-ecs-execution"
    }
  }

  mock_resource "aws_msk_configuration" {
    defaults = {
      arn = "arn:aws:kafka:ap-southeast-2:123456789012:configuration/bidnow-demo/11111111-2222-3333-4444-555555555555-1"
    }
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
    }
  }

  override_data {
    target = data.aws_ecr_images.this
    values = {
      image_ids = [
        { image_digest = "sha256:1111111111111111111111111111111111111111111111111111111111111111", image_tag = "latest" },
        { image_digest = "sha256:2222222222222222222222222222222222222222222222222222222222222222", image_tag = "abc1234" },
      ]
    }
  }

  override_resource {
    target = module.rds.aws_db_instance.this
    values = {
      address = "bidnow-demo-postgres.cxyz12345678.ap-southeast-2.rds.amazonaws.com"
    }
  }

  override_resource {
    target = module.elasticache.aws_elasticache_replication_group.this
    values = {
      primary_endpoint_address = "bidnow-demo-redis.abc123.ng.0001.apse2.cache.amazonaws.com"
    }
  }

  override_resource {
    target = module.msk.aws_msk_cluster.this
    values = {
      bootstrap_brokers_tls = "b-1.bidnowdemo.kafka.ap-southeast-2.amazonaws.com:9094,b-2.bidnowdemo.kafka.ap-southeast-2.amazonaws.com:9094"
    }
  }

  override_resource {
    target = module.s3_media.aws_s3_bucket.this
    values = {
      id                          = "bidnow-demo-media-test"
      arn                         = "arn:aws:s3:::bidnow-demo-media-test"
      bucket_regional_domain_name = "bidnow-demo-media-test.s3.ap-southeast-2.amazonaws.com"
    }
  }

  override_resource {
    target = module.cloudfront.aws_cloudfront_distribution.this
    values = {
      domain_name = "d111111abcdef8.cloudfront.net"
      arn         = "arn:aws:cloudfront::123456789012:distribution/E1TESTDIST"
    }
  }

  override_resource {
    target = module.alb.aws_lb_target_group.frontend
    values = {
      arn = "arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:targetgroup/bidnow-demo-frontend/1111111111111111"
    }
  }

  override_resource {
    target = module.alb.aws_lb_target_group.gateway
    values = {
      arn = "arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:targetgroup/bidnow-demo-gateway/2222222222222222"
    }
  }
}

variables {
  ecr_repository_urls = {
    "frontend"         = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/frontend"
    "api-gateway"      = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/api-gateway"
    "identity-service" = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/identity-service"
    "user-service"     = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/user-service"
    "auction-service"  = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/auction-service"
    "bidding-service"  = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/bidding-service"
    "wallet-service"   = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/wallet-service"
    "media-service"    = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/media-service"
  }
  mail = {
    host     = "smtp.example.test"
    port     = "587"
    username = "mailer@example.test"
    password = "not-a-real-password"
    from     = "no-reply@example.test"
  }
}

run "eight_services_defined" {
  command = apply

  assert {
    condition     = toset(keys(local.services)) == toset(["frontend", "api-gateway", "identity-service", "user-service", "auction-service", "bidding-service", "wallet-service", "media-service"])
    error_message = "Exactly the eight services must be defined (no discovery-service)."
  }

  assert {
    condition     = toset(keys(module.ecs_service)) == toset(keys(local.services))
    error_message = "One ecs-service module instance per service."
  }

  assert {
    condition     = alltrue([for k, v in module.ecs_service : v.service_name == k])
    error_message = "Each ECS service is named after its key (the Service Connect DNS name)."
  }

  assert {
    condition = (
      local.services["frontend"].port == 3000 && local.services["api-gateway"].port == 8080 &&
      local.services["identity-service"].port == 8081 && local.services["user-service"].port == 8082 &&
      local.services["auction-service"].port == 8083 && local.services["bidding-service"].port == 8084 &&
      local.services["wallet-service"].port == 8085 && local.services["media-service"].port == 8086
    )
    error_message = "Service ports must match the spec."
  }

  assert {
    condition = (
      local.services["frontend"].database == null && local.services["api-gateway"].database == null &&
      local.services["identity-service"].database == "identity_db" && local.services["user-service"].database == "user_db" &&
      local.services["auction-service"].database == "auction_db" && local.services["bidding-service"].database == "bidding_db" &&
      local.services["wallet-service"].database == "wallet_db" && local.services["media-service"].database == "media_db"
    )
    error_message = "Databases: none for frontend/api-gateway, <name>_db for the others."
  }

  assert {
    condition = (
      local.services["frontend"].cpu == 256 && local.services["frontend"].memory == 512 &&
      alltrue([for k, s in local.services : s.cpu == 512 && s.memory == 1024 if k != "frontend"])
    )
    error_message = "Frontend is 256/512, every Java service 512/1024."
  }

  assert {
    condition = alltrue([
      for k, s in local.services : s.env["DB_URL"] == "jdbc:postgresql://bidnow-demo-postgres.cxyz12345678.ap-southeast-2.rds.amazonaws.com:5432/${s.database}" && s.env["DB_USERNAME"] == module.rds.master_username && s.secrets["DB_PASSWORD"] == module.secrets.secret_arns["db_password"]
      if s.database != null
    ])
    error_message = "Services with a database get DB_URL from the RDS address, DB_USERNAME and the db_password secret."
  }

  assert {
    condition = alltrue([
      for k, s in local.services : s.init_database == s.database && s.db_host == module.rds.address && s.db_user == module.rds.master_username && s.db_password_secret_arn == module.secrets.secret_arns["db_password"]
      if s.database != null
    ])
    error_message = "db-init inputs must point at the RDS instance and the db_password secret."
  }

  assert {
    condition = alltrue([
      for k in ["frontend", "api-gateway"] : local.services[k].init_database == null && !contains(keys(local.services[k].env), "DB_URL") && !contains(keys(local.services[k].secrets), "DB_PASSWORD")
    ])
    error_message = "frontend and api-gateway have no database wiring."
  }

  assert {
    condition = alltrue([
      for k, s in local.services : (
        s.env["EUREKA_CLIENT_ENABLED"] == "false" &&
        s.env["KAFKA_BOOTSTRAP_SERVERS"] == "b-1.bidnowdemo.kafka.ap-southeast-2.amazonaws.com:9094,b-2.bidnowdemo.kafka.ap-southeast-2.amazonaws.com:9094" &&
        s.env["SPRING_KAFKA_BOOTSTRAP_SERVERS"] == s.env["KAFKA_BOOTSTRAP_SERVERS"] &&
        s.env["SPRING_KAFKA_PROPERTIES_SECURITY_PROTOCOL"] == "SSL"
      ) if k != "frontend"
    ])
    error_message = "Every Java service disables Eureka and uses the MSK TLS brokers over SSL."
  }

  assert {
    condition     = length(local.services["frontend"].env) == 0 && length(local.services["frontend"].secrets) == 0
    error_message = "The frontend image is built with same-origin URLs and needs no runtime env or secrets."
  }

  assert {
    condition     = alltrue([for k, s in local.services : s.subnet_ids == module.network.app_subnet_ids && s.security_group_ids == [module.network.app_sg_id]])
    error_message = "All services run in the app subnets with the app security group."
  }
}

run "only_frontend_and_gateway_have_target_groups" {
  command = apply

  assert {
    condition     = local.services["frontend"].target_group_arn == "arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:targetgroup/bidnow-demo-frontend/1111111111111111"
    error_message = "frontend must use the ALB frontend target group."
  }

  assert {
    condition     = local.services["api-gateway"].target_group_arn == "arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:targetgroup/bidnow-demo-gateway/2222222222222222"
    error_message = "api-gateway must use the ALB gateway target group."
  }

  assert {
    condition     = length([for k, s in local.services : k if s.target_group_arn != null]) == 2
    error_message = "No other service may attach to the ALB."
  }
}

run "bidding_service_has_redis_host" {
  command = apply

  assert {
    condition     = alltrue([for k in ["auction-service", "bidding-service", "media-service"] : local.services[k].env["REDIS_HOST"] == "bidnow-demo-redis.abc123.ng.0001.apse2.cache.amazonaws.com"])
    error_message = "auction, bidding and media get REDIS_HOST from the ElastiCache primary endpoint."
  }

  assert {
    condition     = length([for k, s in local.services : k if contains(keys(s.env), "REDIS_HOST")]) == 3
    error_message = "Only auction, bidding and media use Redis."
  }
}

run "no_secret_values_in_plain_env" {
  command = apply

  assert {
    condition = alltrue(flatten([
      for k, s in local.services : [
        for name in ["DB_PASSWORD", "JWT_SECRET", "MAIL_PASSWORD", "MAIL_USERNAME", "MAIL_HOST", "MAIL_PORT", "MAIL_FROM"] : !contains(keys(s.env), name)
      ]
    ]))
    error_message = "Secret values must never be plain environment variables."
  }

  assert {
    condition = (
      local.services["api-gateway"].secrets["JWT_SECRET"] == module.secrets.secret_arns["jwt_secret"] &&
      local.services["identity-service"].secrets["JWT_SECRET"] == module.secrets.secret_arns["jwt_secret"] &&
      length([for k, s in local.services : k if contains(keys(s.secrets), "JWT_SECRET")]) == 2
    )
    error_message = "JWT_SECRET comes from the jwt_secret secret, for api-gateway and identity-service only."
  }

  assert {
    condition = (
      local.services["media-service"].secrets["MAIL_HOST"] == module.secrets.secret_arns["mail_host"] &&
      local.services["media-service"].secrets["MAIL_PORT"] == module.secrets.secret_arns["mail_port"] &&
      local.services["media-service"].secrets["MAIL_USERNAME"] == module.secrets.secret_arns["mail_username"] &&
      local.services["media-service"].secrets["MAIL_PASSWORD"] == module.secrets.secret_arns["mail_password"] &&
      local.services["media-service"].secrets["MAIL_FROM"] == module.secrets.secret_arns["mail_from"]
    )
    error_message = "media-service gets the five MAIL_* values from their own secrets."
  }

  assert {
    condition     = length([for k, s in local.services : k if contains(keys(s.secrets), "MAIL_PASSWORD")]) == 1
    error_message = "Only media-service sends mail."
  }

  assert {
    condition     = length(distinct(values(module.secrets.secret_arns))) == 7
    error_message = "Mock secret ARNs must be distinct (test sanity, otherwise the ARN checks prove nothing)."
  }

  assert {
    condition     = alltrue([for k, s in local.services : alltrue([for v in values(s.env) : !contains(values(module.secrets.secret_arns), v)])])
    error_message = "Secret ARNs belong in secrets, not env."
  }
}

run "multi_az_true_sets_task_count_two" {
  command = apply

  variables {
    multi_az = true
  }

  assert {
    condition     = alltrue([for k, s in local.services : s.desired_count == 2 && s.min_count == 2 && s.max_count == 4])
    error_message = "multi_az = true runs two tasks per service (max four)."
  }
}

run "single_az_default_task_count_one" {
  command = apply

  assert {
    condition     = alltrue([for k, s in local.services : s.desired_count == 1 && s.min_count == 1 && s.max_count == 2])
    error_message = "Default mode runs one task per service (max two)."
  }
}

run "media_service_task_policy_scoped_to_bucket" {
  command = apply

  assert {
    condition     = length(jsondecode(local.services["media-service"].task_policy_json).Statement) == 1
    error_message = "The media task policy has exactly one statement."
  }

  assert {
    condition = (
      jsondecode(local.services["media-service"].task_policy_json).Statement[0].Effect == "Allow" &&
      toset(jsondecode(local.services["media-service"].task_policy_json).Statement[0].Action) == toset(["s3:PutObject", "s3:GetObject", "s3:DeleteObject"])
    )
    error_message = "media-service may only Put/Get/Delete objects."
  }

  assert {
    condition     = jsondecode(local.services["media-service"].task_policy_json).Statement[0].Resource == "arn:aws:s3:::bidnow-demo-media-test/*"
    error_message = "The media task policy must be scoped to the objects of the media bucket only."
  }

  assert {
    condition     = length([for k, s in local.services : k if s.task_policy_json != null]) == 1
    error_message = "No other service gets a task policy."
  }

  assert {
    condition = (
      local.services["media-service"].env["AWS_REGION"] == "ap-southeast-2" &&
      local.services["media-service"].env["AWS_BUCKET_NAME"] == "bidnow-demo-media-test" &&
      local.services["media-service"].env["CDN_BASE_URL"] == "https://d111111abcdef8.cloudfront.net" &&
      local.services["media-service"].env["APP_FRONTEND_BASE_URL"] == "https://d111111abcdef8.cloudfront.net" &&
      local.services["media-service"].env["FRONTEND_BASE_URL"] == "https://d111111abcdef8.cloudfront.net"
    )
    error_message = "media-service gets region, bucket, CDN and frontend URLs from the real resources."
  }
}

run "gateway_has_all_six_service_urls" {
  command = apply

  assert {
    condition = (
      local.services["api-gateway"].env["IDENTITY_SERVICE_URL"] == "http://identity-service:8081" &&
      local.services["api-gateway"].env["USER_SERVICE_URL"] == "http://user-service:8082" &&
      local.services["api-gateway"].env["AUCTION_SERVICE_URL"] == "http://auction-service:8083" &&
      local.services["api-gateway"].env["BIDDING_SERVICE_URL"] == "http://bidding-service:8084" &&
      local.services["api-gateway"].env["WALLET_SERVICE_URL"] == "http://wallet-service:8085" &&
      local.services["api-gateway"].env["MEDIA_SERVICE_URL"] == "http://media-service:8086"
    )
    error_message = "The gateway routes to every service through its Service Connect name and port."
  }

  assert {
    condition = alltrue([
      for k in ["identity-service", "user-service", "auction-service", "bidding-service", "wallet-service", "media-service"] :
      local.services["api-gateway"].env["${upper(replace(trimsuffix(k, "-service"), "-", "_"))}_SERVICE_URL"] == "http://${k}:${local.services[k].port}"
    ])
    error_message = "Each gateway URL must match the target service's own name and port."
  }
}

run "gateway_allows_cloudfront_origin" {
  command = apply

  assert {
    condition     = local.services["api-gateway"].env["CORS_ALLOWED_ORIGINS"] == "https://d111111abcdef8.cloudfront.net"
    error_message = "api-gateway must allow the CloudFront origin in CORS."
  }

  assert {
    condition     = [for k, s in local.services : k if contains(keys(s.env), "CORS_ALLOWED_ORIGINS")] == ["api-gateway"]
    error_message = "Only api-gateway gets CORS_ALLOWED_ORIGINS."
  }
}

run "feign_callers_have_their_service_urls" {
  command = apply

  assert {
    condition = (
      local.services["bidding-service"].env["USER_SERVICE_URL"] == "http://user-service:8082" &&
      local.services["bidding-service"].env["AUCTION_SERVICE_URL"] == "http://auction-service:8083" &&
      local.services["bidding-service"].env["WALLET_SERVICE_URL"] == "http://wallet-service:8085"
    )
    error_message = "bidding-service calls user, auction and wallet."
  }

  assert {
    condition     = local.services["auction-service"].env["USER_SERVICE_URL"] == "http://user-service:8082"
    error_message = "auction-service calls user."
  }

  assert {
    condition     = local.services["identity-service"].env["USER_SERVICE_URL"] == "http://user-service:8082"
    error_message = "identity-service calls user."
  }

  assert {
    condition = (
      local.services["media-service"].env["IDENTITY_SERVICE_URL"] == "http://identity-service:8081" &&
      local.services["media-service"].env["USER_SERVICE_URL"] == "http://user-service:8082"
    )
    error_message = "media-service calls identity and user."
  }

  assert {
    condition = (
      length([for n in keys(local.services["user-service"].env) : n if endswith(n, "_SERVICE_URL")]) == 0 &&
      length([for n in keys(local.services["wallet-service"].env) : n if endswith(n, "_SERVICE_URL")]) == 0 &&
      length([for n in keys(local.services["bidding-service"].env) : n if endswith(n, "_SERVICE_URL")]) == 3 &&
      length([for n in keys(local.services["media-service"].env) : n if endswith(n, "_SERVICE_URL")]) == 2
    )
    error_message = "Only Feign callers get service URLs, and only the ones they call."
  }
}

run "cluster_is_named_bidnow_demo" {
  command = apply

  assert {
    condition     = module.ecs_cluster.cluster_name == "bidnow-demo" && output.cluster_name == "bidnow-demo"
    error_message = "The cluster must be named bidnow-demo (the bootstrap deploy role is scoped to it)."
  }

  assert {
    condition     = alltrue([for k, s in local.services : s.cluster_name == "bidnow-demo" && s.cluster_arn == module.ecs_cluster.cluster_arn && s.namespace_arn == module.ecs_cluster.namespace_arn && s.execution_role_arn == module.ecs_cluster.execution_role_arn])
    error_message = "Every service runs on the demo cluster with its namespace and execution role."
  }
}

run "outputs_expose_entry_points" {
  command = apply

  assert {
    condition = (
      output.cloudfront_url == "https://d111111abcdef8.cloudfront.net" &&
      output.rds_address == "bidnow-demo-postgres.cxyz12345678.ap-southeast-2.rds.amazonaws.com" &&
      output.msk_bootstrap_brokers_tls == "b-1.bidnowdemo.kafka.ap-southeast-2.amazonaws.com:9094,b-2.bidnowdemo.kafka.ap-southeast-2.amazonaws.com:9094" &&
      output.media_bucket == "bidnow-demo-media-test" &&
      output.alb_dns_name == module.alb.dns_name
    )
    error_message = "Outputs must expose the real entry points."
  }
}

run "image_uses_ecr_url_and_tag" {
  command = apply

  variables {
    image_tag = "abc1234"
  }

  assert {
    condition     = alltrue([for k, s in local.services : s.image == "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/${k}:abc1234"])
    error_message = "Each service image is <its ECR url>:<image_tag>."
  }
}

run "missing_ecr_repository_key_rejected" {
  command = plan

  variables {
    ecr_repository_urls = {
      "frontend"         = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/frontend"
      "api-gateway"      = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/api-gateway"
      "identity-service" = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/identity-service"
      "user-service"     = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/user-service"
      "auction-service"  = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/auction-service"
      "bidding-service"  = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/bidding-service"
      "wallet-service"   = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/wallet-service"
    }
  }

  expect_failures = [var.ecr_repository_urls]
}

run "ecr_lookup_uses_repository_from_url" {
  command = plan

  assert {
    condition     = alltrue([for k, d in data.aws_ecr_images.this : d.repository_name == k && d.registry_id == "123456789012"])
    error_message = "Each image lookup targets the repository and registry parsed from its ECR URL."
  }

  assert {
    condition     = toset(keys(data.aws_ecr_images.this)) == toset(keys(local.services))
    error_message = "Every deployed service must have its image checked."
  }
}

run "missing_image_tag_fails_with_push_first_message" {
  command = plan

  variables {
    image_tag = "not-pushed-yet"
  }

  expect_failures = [terraform_data.ecr_images_pushed]
}

run "one_empty_repository_fails" {
  command = plan

  override_data {
    target = data.aws_ecr_images.this["media-service"]
    values = {
      image_ids = []
    }
  }

  expect_failures = [terraform_data.ecr_images_pushed]
}
