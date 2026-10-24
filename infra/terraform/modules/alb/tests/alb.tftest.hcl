mock_provider "aws" {}

variables {
  name                = "bidnow-test"
  vpc_id              = "vpc-0123456789abcdef0"
  public_subnet_ids   = ["subnet-aaaa1111", "subnet-bbbb2222"]
  alb_sg_id           = "sg-0123456789abcdef0"
  origin_verify_value = "test-origin-secret"
}

run "listener_default_action_is_403" {
  command = plan

  assert {
    condition     = length(aws_lb_listener.http.default_action) == 1 && aws_lb_listener.http.default_action[0].type == "fixed-response"
    error_message = "Listener default action must be a single fixed-response."
  }

  assert {
    condition     = aws_lb_listener.http.default_action[0].fixed_response[0].status_code == "403" && aws_lb_listener.http.default_action[0].fixed_response[0].content_type == "text/plain" && aws_lb_listener.http.default_action[0].fixed_response[0].message_body == "Forbidden"
    error_message = "Default action must return 403 text/plain 'Forbidden'."
  }
}

run "listener_is_http_80_only" {
  command = plan

  assert {
    condition     = aws_lb_listener.http.port == 80 && aws_lb_listener.http.protocol == "HTTP"
    error_message = "The only listener must be HTTP:80."
  }

  assert {
    condition     = aws_lb_listener.http.certificate_arn == null
    error_message = "No certificate is expected on the HTTP listener."
  }
}

run "every_forward_rule_requires_origin_header" {
  command = plan

  assert {
    condition = alltrue([
      for r in [aws_lb_listener_rule.gateway, aws_lb_listener_rule.frontend] :
      length([
        for c in r.condition : c
        if length(c.http_header) == 1 && one(c.http_header).http_header_name == "X-Origin-Verify" && one(c.http_header).values == toset(["test-origin-secret"])
      ]) == 1
    ])
    error_message = "Every forward rule needs exactly one X-Origin-Verify header condition equal to the configured value."
  }

  assert {
    condition = alltrue([
      for r in [aws_lb_listener_rule.gateway, aws_lb_listener_rule.frontend] :
      length(r.condition) == 2 && length(r.action) == 1 && r.action[0].type == "forward"
    ])
    error_message = "Each rule must combine the header and a path condition and forward."
  }
}

run "gateway_rule_matches_api_and_ws_paths" {
  command = plan

  assert {
    condition = anytrue([
      for c in aws_lb_listener_rule.gateway.condition :
      length(c.path_pattern) == 1 && one(c.path_pattern).values == toset(["/api/*", "/ws-notifications/*"])
    ])
    error_message = "Gateway rule must match exactly /api/* and /ws-notifications/*."
  }

  assert {
    condition     = aws_lb_listener_rule.gateway.priority == 10
    error_message = "Gateway rule must have priority 10."
  }
}

run "frontend_rule_is_catch_all_with_lower_priority_than_gateway" {
  command = plan

  assert {
    condition = anytrue([
      for c in aws_lb_listener_rule.frontend.condition :
      length(c.path_pattern) == 1 && one(c.path_pattern).values == toset(["/*"])
    ])
    error_message = "Frontend rule must be the /* catch-all."
  }

  assert {
    condition     = aws_lb_listener_rule.frontend.priority == 20 && aws_lb_listener_rule.frontend.priority > aws_lb_listener_rule.gateway.priority
    error_message = "Frontend rule (20) must be evaluated after the gateway rule (10)."
  }
}

# Applied under the mock provider so target group arns are known and distinct.
run "rules_forward_to_matching_target_groups" {
  command = apply

  # The provider validates ARN syntax, so give the mocks well-formed, distinct arns.
  override_resource {
    target = aws_lb.this
    values = {
      arn = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:loadbalancer/app/bidnow-test-alb/1111111111111111"
    }
  }

  override_resource {
    target = aws_lb_listener.http
    values = {
      arn = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:listener/app/bidnow-test-alb/1111111111111111/2222222222222222"
    }
  }

  override_resource {
    target = aws_lb_target_group.frontend
    values = {
      arn = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:targetgroup/bidnow-test-frontend/3333333333333333"
    }
  }

  override_resource {
    target = aws_lb_target_group.gateway
    values = {
      arn = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:targetgroup/bidnow-test-gateway/4444444444444444"
    }
  }

  assert {
    condition     = aws_lb_target_group.frontend.arn != aws_lb_target_group.gateway.arn
    error_message = "Mock arns for the target groups must be distinct (test sanity)."
  }

  assert {
    condition     = aws_lb_listener_rule.gateway.action[0].target_group_arn == aws_lb_target_group.gateway.arn && aws_lb_listener_rule.frontend.action[0].target_group_arn == aws_lb_target_group.frontend.arn
    error_message = "Gateway rule must forward to the gateway target group and frontend rule to the frontend one."
  }

  assert {
    condition     = aws_lb_listener_rule.gateway.listener_arn == aws_lb_listener.http.arn && aws_lb_listener_rule.frontend.listener_arn == aws_lb_listener.http.arn && aws_lb_listener.http.load_balancer_arn == aws_lb.this.arn
    error_message = "Rules must be attached to the HTTP listener of the ALB."
  }

  assert {
    condition     = output.frontend_target_group_arn == aws_lb_target_group.frontend.arn && output.gateway_target_group_arn == aws_lb_target_group.gateway.arn && output.arn == aws_lb.this.arn
    error_message = "Outputs must expose the real resource arns."
  }
}

run "target_groups_are_ip_type" {
  command = plan

  assert {
    condition     = aws_lb_target_group.frontend.target_type == "ip" && aws_lb_target_group.gateway.target_type == "ip"
    error_message = "Fargate awsvpc tasks require ip target groups."
  }

  assert {
    condition     = aws_lb_target_group.frontend.port == 3000 && aws_lb_target_group.gateway.port == 8080 && aws_lb_target_group.frontend.protocol == "HTTP" && aws_lb_target_group.gateway.protocol == "HTTP"
    error_message = "Frontend serves HTTP on 3000 and gateway HTTP on 8080."
  }

  assert {
    condition     = aws_lb_target_group.frontend.vpc_id == "vpc-0123456789abcdef0" && aws_lb_target_group.gateway.vpc_id == "vpc-0123456789abcdef0"
    error_message = "Target groups must live in the given VPC."
  }

  assert {
    condition     = aws_lb_target_group.frontend.deregistration_delay == "30" && aws_lb_target_group.gateway.deregistration_delay == "30"
    error_message = "Deregistration delay should be 30s for quick rollouts."
  }
}

run "gateway_health_check_path" {
  command = plan

  assert {
    condition     = aws_lb_target_group.gateway.health_check[0].path == "/actuator/health" && aws_lb_target_group.gateway.health_check[0].matcher == "200"
    error_message = "Gateway health check must be /actuator/health expecting 200."
  }

  assert {
    condition     = aws_lb_target_group.frontend.health_check[0].path == "/healthz" && aws_lb_target_group.frontend.health_check[0].matcher == "200-399"
    error_message = "Frontend health check must be /healthz expecting 200-399."
  }
}

run "load_balancer_settings" {
  command = plan

  assert {
    condition     = aws_lb.this.load_balancer_type == "application" && aws_lb.this.internal == false
    error_message = "Expected an internet-facing application load balancer."
  }

  assert {
    condition     = aws_lb.this.idle_timeout == 120 && aws_lb.this.drop_invalid_header_fields == true
    error_message = "Idle timeout must be 120s (websockets) and invalid headers dropped."
  }

  assert {
    condition     = toset(aws_lb.this.subnets) == toset(["subnet-aaaa1111", "subnet-bbbb2222"]) && aws_lb.this.security_groups == toset(["sg-0123456789abcdef0"])
    error_message = "ALB must use the public subnets and the supplied security group."
  }
}
