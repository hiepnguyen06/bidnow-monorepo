mock_provider "aws" {}

variables {
  name                              = "bidnow-test"
  alb_dns_name                      = "bidnow-test-alb-123.ap-southeast-1.elb.amazonaws.com"
  origin_verify_value               = "test-origin-secret"
  media_bucket_id                   = "bidnow-test-media-abc"
  media_bucket_arn                  = "arn:aws:s3:::bidnow-test-media-abc"
  media_bucket_regional_domain_name = "bidnow-test-media-abc.s3.ap-southeast-1.amazonaws.com"
}

run "uploads_behavior_targets_s3" {
  command = plan

  assert {
    condition     = length(aws_cloudfront_distribution.this.ordered_cache_behavior) == 4
    error_message = "Expected exactly four ordered behaviors."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.ordered_cache_behavior[0].path_pattern == "/uploads/*" && aws_cloudfront_distribution.this.ordered_cache_behavior[0].target_origin_id == "media"
    error_message = "/uploads/* must be the first behavior and target the media origin."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.ordered_cache_behavior[0].allowed_methods == toset(["GET", "HEAD", "OPTIONS"]) && aws_cloudfront_distribution.this.ordered_cache_behavior[0].compress == true
    error_message = "/uploads/* must allow GET/HEAD/OPTIONS only and compress."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.ordered_cache_behavior[0].cache_policy_id == "658327ea-f89d-4fab-a63d-7e88639e58f6"
    error_message = "/uploads/* must use the managed CachingOptimized policy."
  }
}

run "api_and_ws_behaviors_not_cached" {
  command = plan

  assert {
    condition = alltrue([
      for b in aws_cloudfront_distribution.this.ordered_cache_behavior :
      b.cache_policy_id == "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" && b.origin_request_policy_id == "b689b0a8-53d0-40ab-baf2-68738e2966ac" && b.target_origin_id == "alb" && b.allowed_methods == toset(["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"])
      if contains(["/api/*", "/ws-notifications/*"], b.path_pattern)
    ])
    error_message = "/api/* and /ws-notifications/* must use CachingDisabled, AllViewerExceptHostHeader, all methods, ALB origin."
  }

  assert {
    condition     = length([for b in aws_cloudfront_distribution.this.ordered_cache_behavior : b if contains(["/api/*", "/ws-notifications/*"], b.path_pattern)]) == 2
    error_message = "Both /api/* and /ws-notifications/* behaviors must exist."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.default_cache_behavior[0].cache_policy_id == "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" && aws_cloudfront_distribution.this.default_cache_behavior[0].origin_request_policy_id == "b689b0a8-53d0-40ab-baf2-68738e2966ac" && aws_cloudfront_distribution.this.default_cache_behavior[0].target_origin_id == "alb"
    error_message = "Default behavior must go to the ALB uncached with AllViewerExceptHostHeader."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.default_cache_behavior[0].allowed_methods == toset(["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"])
    error_message = "Default behavior must allow all methods."
  }
}

run "static_assets_behavior_is_cached_from_alb" {
  command = plan

  assert {
    condition     = anytrue([for b in aws_cloudfront_distribution.this.ordered_cache_behavior : b.target_origin_id == "alb" && b.allowed_methods == toset(["GET", "HEAD"]) && b.cache_policy_id == "658327ea-f89d-4fab-a63d-7e88639e58f6" && b.compress == true if b.path_pattern == "/_next/static/*"])
    error_message = "/_next/static/* must be cached (CachingOptimized), GET/HEAD, compressed, served from the ALB."
  }

  assert {
    condition     = [for b in aws_cloudfront_distribution.this.ordered_cache_behavior : b.path_pattern] == ["/uploads/*", "/api/*", "/ws-notifications/*", "/_next/static/*"]
    error_message = "Ordered behaviors must be /uploads, /api, /ws-notifications, /_next/static in that order."
  }
}

run "alb_origin_sends_verify_header" {
  command = apply

  override_resource {
    target = aws_cloudfront_origin_access_control.media
    values = {
      id = "E2OACEXAMPLE01"
    }
  }

  assert {
    condition = anytrue([
      for o in aws_cloudfront_distribution.this.origin :
      o.origin_id == "alb" && o.domain_name == "bidnow-test-alb-123.ap-southeast-1.elb.amazonaws.com" && length(o.custom_header) == 1 && one(o.custom_header).name == "X-Origin-Verify" && one(o.custom_header).value == "test-origin-secret"
    ])
    error_message = "ALB origin must send X-Origin-Verify with the configured secret."
  }

  assert {
    condition     = length(aws_cloudfront_distribution.this.origin) == 2
    error_message = "Exactly two origins (alb, media) are expected."
  }
}

run "alb_origin_is_http_only_port_80" {
  command = apply

  override_resource {
    target = aws_cloudfront_origin_access_control.media
    values = {
      id = "E2OACEXAMPLE01"
    }
  }

  assert {
    condition = anytrue([
      for o in aws_cloudfront_distribution.this.origin :
      o.origin_id == "alb" && length(o.custom_origin_config) == 1 && one(o.custom_origin_config).origin_protocol_policy == "http-only" && one(o.custom_origin_config).http_port == 80 && one(o.custom_origin_config).origin_read_timeout == 60 && one(o.custom_origin_config).origin_keepalive_timeout == 60
    ])
    error_message = "ALB origin must be http-only on port 80 with 60s read and keepalive timeouts."
  }
}

run "media_origin_uses_oac" {
  command = apply

  override_resource {
    target = aws_cloudfront_origin_access_control.media
    values = {
      id = "E2OACEXAMPLE01"
    }
  }

  assert {
    condition = anytrue([
      for o in aws_cloudfront_distribution.this.origin :
      o.origin_id == "media" && o.domain_name == "bidnow-test-media-abc.s3.ap-southeast-1.amazonaws.com" && o.origin_access_control_id == "E2OACEXAMPLE01" && length(o.custom_origin_config) == 0 && length(o.custom_header) == 0
    ])
    error_message = "Media origin must be the bucket regional domain using the OAC and no custom origin config."
  }

  assert {
    condition     = aws_cloudfront_origin_access_control.media.origin_access_control_origin_type == "s3" && aws_cloudfront_origin_access_control.media.signing_protocol == "sigv4" && aws_cloudfront_origin_access_control.media.signing_behavior == "always"
    error_message = "OAC must be s3 / sigv4 / always."
  }
}

run "default_behavior_and_ordered_behaviors_redirect_to_https" {
  command = plan

  assert {
    condition     = aws_cloudfront_distribution.this.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https"
    error_message = "Default behavior must redirect to HTTPS."
  }

  assert {
    condition     = alltrue([for b in aws_cloudfront_distribution.this.ordered_cache_behavior : b.viewer_protocol_policy == "redirect-to-https"])
    error_message = "Every ordered behavior must redirect to HTTPS."
  }
}

run "distribution_settings" {
  command = plan

  assert {
    condition     = aws_cloudfront_distribution.this.enabled == true && aws_cloudfront_distribution.this.is_ipv6_enabled == true && aws_cloudfront_distribution.this.price_class == "PriceClass_100"
    error_message = "Distribution must be enabled, IPv6 and PriceClass_100."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.viewer_certificate[0].cloudfront_default_certificate == true && aws_cloudfront_distribution.this.restrictions[0].geo_restriction[0].restriction_type == "none"
    error_message = "Default CloudFront certificate and no geo restriction expected."
  }
}

run "bucket_policy_allows_only_this_distribution" {
  command = apply
  # Separate state: overrides only take effect when a resource is created, and earlier apply runs already created mock-valued ones.
  state_key = "wiring"

  override_resource {
    target = aws_cloudfront_origin_access_control.media
    values = {
      id = "E2OACEXAMPLE01"
    }
  }

  override_resource {
    target = aws_cloudfront_distribution.this
    values = {
      arn         = "arn:aws:cloudfront::123456789012:distribution/E1ABCDEFGHIJKL"
      domain_name = "d111111abcdef8.cloudfront.net"
    }
  }

  assert {
    condition     = aws_s3_bucket_policy.media.bucket == "bidnow-test-media-abc"
    error_message = "Policy must attach to the media bucket."
  }

  assert {
    condition     = length(jsondecode(aws_s3_bucket_policy.media.policy).Statement) == 1
    error_message = "Policy must have exactly one statement."
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.media.policy).Statement[0].Effect == "Allow" && jsondecode(aws_s3_bucket_policy.media.policy).Statement[0].Action == "s3:GetObject" && jsondecode(aws_s3_bucket_policy.media.policy).Statement[0].Resource == "arn:aws:s3:::bidnow-test-media-abc/*"
    error_message = "Statement must allow only s3:GetObject on the bucket objects."
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.media.policy).Statement[0].Principal == { Service = "cloudfront.amazonaws.com" }
    error_message = "Principal must be the CloudFront service only."
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.media.policy).Statement[0].Condition.StringEquals["AWS:SourceArn"] == aws_cloudfront_distribution.this.arn && aws_cloudfront_distribution.this.arn == "arn:aws:cloudfront::123456789012:distribution/E1ABCDEFGHIJKL"
    error_message = "SourceArn condition must equal this distribution's ARN."
  }

  assert {
    condition     = output.distribution_arn == aws_cloudfront_distribution.this.arn && output.domain_name == "d111111abcdef8.cloudfront.net"
    error_message = "Outputs must expose the distribution arn and domain."
  }
}

run "cors_allows_put_from_distribution_domain" {
  command = apply
  # Separate state: overrides only take effect when a resource is created, and earlier apply runs already created mock-valued ones.
  state_key = "wiring"

  override_resource {
    target = aws_cloudfront_origin_access_control.media
    values = {
      id = "E2OACEXAMPLE01"
    }
  }

  override_resource {
    target = aws_cloudfront_distribution.this
    values = {
      arn         = "arn:aws:cloudfront::123456789012:distribution/E1ABCDEFGHIJKL"
      domain_name = "d111111abcdef8.cloudfront.net"
    }
  }

  assert {
    condition     = aws_s3_bucket_cors_configuration.media.bucket == "bidnow-test-media-abc" && length(aws_s3_bucket_cors_configuration.media.cors_rule) == 1
    error_message = "Exactly one CORS rule on the media bucket expected."
  }

  assert {
    condition     = one(aws_s3_bucket_cors_configuration.media.cors_rule).allowed_origins == toset(["https://${aws_cloudfront_distribution.this.domain_name}"]) && aws_cloudfront_distribution.this.domain_name == "d111111abcdef8.cloudfront.net"
    error_message = "Allowed origin must be https:// plus the distribution domain only."
  }

  assert {
    condition     = one(aws_s3_bucket_cors_configuration.media.cors_rule).allowed_methods == toset(["PUT", "GET", "HEAD"]) && one(aws_s3_bucket_cors_configuration.media.cors_rule).allowed_headers == toset(["*"]) && one(aws_s3_bucket_cors_configuration.media.cors_rule).expose_headers == toset(["ETag"]) && one(aws_s3_bucket_cors_configuration.media.cors_rule).max_age_seconds == 3000
    error_message = "CORS rule must allow PUT/GET/HEAD, all headers, expose ETag, max age 3000."
  }
}
