locals {
  service_names = [
    "frontend",
    "api-gateway",
    "identity-service",
    "user-service",
    "auction-service",
    "bidding-service",
    "wallet-service",
    "media-service",
  ]

  # Service Connect publishes each service as <name>:<port> in the bidnow.local namespace.
  service_urls = {
    identity = "http://identity-service:8081"
    user     = "http://user-service:8082"
    auction  = "http://auction-service:8083"
    bidding  = "http://bidding-service:8084"
    wallet   = "http://wallet-service:8085"
    media    = "http://media-service:8086"
  }

  public_url = "https://${module.cloudfront.domain_name}"

  # Per-service settings. secrets maps an env var name to a Secrets Manager key of module.secrets.
  service_specs = {
    "frontend" = {
      port     = 3000
      database = null
      cpu      = 256
      memory   = 512
      # Browser URLs are same-origin and baked into the image at build time. Server Components cannot
      # fetch a relative URL, so they call the gateway directly over Service Connect.
      env = {
        API_INTERNAL_URL = "http://api-gateway:8080"
      }
      secrets = {}
    }
    "api-gateway" = {
      port     = 8080
      database = null
      cpu      = 512
      memory   = 1024
      env = {
        IDENTITY_SERVICE_URL = local.service_urls.identity
        USER_SERVICE_URL     = local.service_urls.user
        AUCTION_SERVICE_URL  = local.service_urls.auction
        BIDDING_SERVICE_URL  = local.service_urls.bidding
        WALLET_SERVICE_URL   = local.service_urls.wallet
        MEDIA_SERVICE_URL    = local.service_urls.media
        # Browsers send Origin: https://<cloudfront domain> while the gateway sees the ALB as Host.
        CORS_ALLOWED_ORIGINS = local.public_url
      }
      secrets = { JWT_SECRET = "jwt_secret" }
    }
    "identity-service" = {
      port     = 8081
      database = "identity_db"
      cpu      = 512
      memory   = 1024
      env = {
        USER_SERVICE_URL = local.service_urls.user
      }
      secrets = { JWT_SECRET = "jwt_secret" }
    }
    "user-service" = {
      port     = 8082
      database = "user_db"
      cpu      = 512
      memory   = 1024
      env      = {}
      secrets  = {}
    }
    "auction-service" = {
      port     = 8083
      database = "auction_db"
      cpu      = 512
      memory   = 1024
      env = {
        REDIS_HOST       = module.elasticache.address
        USER_SERVICE_URL = local.service_urls.user
      }
      secrets = {}
    }
    "bidding-service" = {
      port     = 8084
      database = "bidding_db"
      cpu      = 512
      memory   = 1024
      env = {
        REDIS_HOST          = module.elasticache.address
        USER_SERVICE_URL    = local.service_urls.user
        AUCTION_SERVICE_URL = local.service_urls.auction
        WALLET_SERVICE_URL  = local.service_urls.wallet
      }
      secrets = {}
    }
    "wallet-service" = {
      port     = 8085
      database = "wallet_db"
      cpu      = 512
      memory   = 1024
      env      = {}
      secrets  = {}
    }
    "media-service" = {
      port     = 8086
      database = "media_db"
      cpu      = 512
      memory   = 1024
      env = {
        REDIS_HOST            = module.elasticache.address
        IDENTITY_SERVICE_URL  = local.service_urls.identity
        USER_SERVICE_URL      = local.service_urls.user
        AWS_REGION            = var.aws_region
        AWS_BUCKET_NAME       = module.s3_media.bucket_id
        CDN_BASE_URL          = local.public_url
        APP_FRONTEND_BASE_URL = local.public_url
        # application.yml reads app.frontend.base-url from ${FRONTEND_BASE_URL}; set both names.
        FRONTEND_BASE_URL = local.public_url
      }
      secrets = {
        MAIL_HOST     = "mail_host"
        MAIL_PORT     = "mail_port"
        MAIL_USERNAME = "mail_username"
        MAIL_PASSWORD = "mail_password"
        MAIL_FROM     = "mail_from"
      }
    }
  }

  # Every Spring Boot service: no Eureka, Kafka over TLS to MSK.
  java_env = {
    EUREKA_CLIENT_ENABLED                     = "false"
    KAFKA_BOOTSTRAP_SERVERS                   = module.msk.bootstrap_brokers_tls
    SPRING_KAFKA_BOOTSTRAP_SERVERS            = module.msk.bootstrap_brokers_tls
    SPRING_KAFKA_PROPERTIES_SECURITY_PROTOCOL = "SSL"
  }

  media_task_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
      Resource = "${module.s3_media.bucket_arn}/*"
    }]
  })

  target_group_arns = {
    "frontend"    = module.alb.frontend_target_group_arn
    "api-gateway" = module.alb.gateway_target_group_arn
  }

  services = {
    for name in local.service_names : name => {
      port     = local.service_specs[name].port
      database = local.service_specs[name].database
      cpu      = local.service_specs[name].cpu
      memory   = local.service_specs[name].memory
      image    = "${var.ecr_repository_urls[name]}:${var.image_tag}"

      desired_count = var.multi_az ? 2 : 1
      min_count     = var.multi_az ? 2 : 1
      max_count     = var.multi_az ? 4 : 2

      cluster_name       = module.ecs_cluster.cluster_name
      cluster_arn        = module.ecs_cluster.cluster_arn
      namespace_arn      = module.ecs_cluster.namespace_arn
      execution_role_arn = module.ecs_cluster.execution_role_arn
      subnet_ids         = module.network.app_subnet_ids
      security_group_ids = [module.network.app_sg_id]
      target_group_arn   = lookup(local.target_group_arns, name, null)

      env = merge(
        name == "frontend" ? {} : local.java_env,
        local.service_specs[name].database == null ? {} : {
          DB_URL      = "jdbc:postgresql://${module.rds.address}:5432/${local.service_specs[name].database}"
          DB_USERNAME = module.rds.master_username
        },
        local.service_specs[name].env,
      )

      secrets = merge(
        local.service_specs[name].database == null ? {} : { DB_PASSWORD = module.secrets.secret_arns["db_password"] },
        { for env_name, key in local.service_specs[name].secrets : env_name => module.secrets.secret_arns[key] },
      )

      init_database          = local.service_specs[name].database
      db_host                = local.service_specs[name].database == null ? null : module.rds.address
      db_user                = local.service_specs[name].database == null ? null : module.rds.master_username
      db_password_secret_arn = local.service_specs[name].database == null ? null : module.secrets.secret_arns["db_password"]

      task_policy_json = name == "media-service" ? local.media_task_policy_json : null
    }
  }
}
