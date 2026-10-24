resource "aws_lb" "this" {
  name                       = "${var.name}-alb"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = var.public_subnet_ids
  security_groups            = [var.alb_sg_id]
  idle_timeout               = 120
  drop_invalid_header_fields = true

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

resource "aws_lb_target_group" "frontend" {
  name                 = "${var.name}-frontend"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  protocol             = "HTTP"
  port                 = 3000
  deregistration_delay = 30

  health_check {
    path    = "/healthz"
    matcher = "200-399"
  }

  tags = merge(var.tags, { Name = "${var.name}-frontend" })
}

resource "aws_lb_target_group" "gateway" {
  name                 = "${var.name}-gateway"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  protocol             = "HTTP"
  port                 = 8080
  deregistration_delay = 30

  health_check {
    path    = "/actuator/health"
    matcher = "200"
  }

  tags = merge(var.tags, { Name = "${var.name}-gateway" })
}

# Anything that does not carry the CloudFront origin-verify header is rejected.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }

  tags = var.tags
}

resource "aws_lb_listener_rule" "gateway" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway.arn
  }

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [var.origin_verify_value]
    }
  }

  condition {
    path_pattern {
      values = ["/api/*", "/ws-notifications/*"]
    }
  }

  tags = var.tags
}

resource "aws_lb_listener_rule" "frontend" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [var.origin_verify_value]
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  tags = var.tags
}
