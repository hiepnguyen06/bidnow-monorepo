mock_provider "aws" {
  override_data {
    target = data.aws_ec2_managed_prefix_list.cloudfront
    values = {
      id   = "pl-3b927c52"
      name = "com.amazonaws.global.cloudfront.origin-facing"
    }
  }

  override_data {
    target = data.aws_vpc_endpoint_service.s3
    values = {
      service_name = "com.amazonaws.ap-southeast-1.s3"
    }
  }
}

variables {
  name = "bidnow-test"
  azs  = ["ap-southeast-1a", "ap-southeast-1b"]
}

run "single_nat_by_default" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Expected exactly one NAT gateway when multi_az is false."
  }

  assert {
    condition     = length(aws_eip.nat) == 1
    error_message = "Expected exactly one NAT elastic IP when multi_az is false."
  }

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.app) == 2 && length(aws_subnet.data) == 2
    error_message = "Expected two public, two app and two data subnets."
  }

  assert {
    condition = (
      [for s in aws_subnet.public : s.cidr_block] == ["10.0.0.0/24", "10.0.1.0/24"] &&
      [for s in aws_subnet.app : s.cidr_block] == ["10.0.10.0/24", "10.0.11.0/24"] &&
      [for s in aws_subnet.data : s.cidr_block] == ["10.0.20.0/24", "10.0.21.0/24"]
    )
    error_message = "Subnet CIDRs do not match the design."
  }
}

run "two_nats_when_multi_az" {
  command = plan

  variables {
    multi_az = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "Expected one NAT gateway per AZ when multi_az is true."
  }

  assert {
    condition     = length(aws_eip.nat) == 2
    error_message = "Expected one NAT elastic IP per AZ when multi_az is true."
  }

  assert {
    condition     = length(aws_route.app_nat) == 2
    error_message = "Each app route table needs a default route through a NAT gateway."
  }
}

run "data_route_tables_have_no_default_route" {
  command = plan

  assert {
    condition     = length(aws_route_table.data) == 2
    error_message = "Expected one route table per data subnet."
  }

  assert {
    condition     = alltrue([for rt in aws_route_table.data : length(rt.route) == 0])
    error_message = "Data route tables must not contain any inline routes (no 0.0.0.0/0)."
  }

  assert {
    condition     = length(aws_route.app_nat) == 2 && aws_route.public_internet.destination_cidr_block == "0.0.0.0/0"
    error_message = "Only the app (via NAT) and public (via IGW) tiers may have default routes."
  }

  assert {
    condition     = length(aws_route_table_association.data) == 2
    error_message = "Each data subnet must be associated with a data route table."
  }
}

run "alb_sg_ingress_is_prefix_list_only" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_http.prefix_list_id == "pl-3b927c52"
    error_message = "ALB ingress must come from the CloudFront origin-facing prefix list."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_http.cidr_ipv4 == null && aws_vpc_security_group_ingress_rule.alb_http.cidr_ipv6 == null
    error_message = "ALB ingress must not use any CIDR block."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_http.from_port == 80 && aws_vpc_security_group_ingress_rule.alb_http.to_port == 80
    error_message = "ALB ingress must be port 80 only."
  }

  assert {
    condition     = length(aws_security_group.alb.ingress) == 0
    error_message = "ALB security group must not carry inline ingress rules."
  }
}

run "app_sg_and_s3_endpoint" {
  command = plan

  assert {
    condition     = toset([for r in aws_vpc_security_group_ingress_rule.app_from_alb : r.from_port]) == toset([3000, 8080])
    error_message = "App SG must accept 3000 and 8080 from the ALB SG."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_self.ip_protocol == "-1"
    error_message = "App SG must allow all traffic from itself for Service Connect."
  }

  assert {
    condition     = aws_vpc_endpoint.s3.service_name == "com.amazonaws.ap-southeast-1.s3" && aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
    error_message = "Expected an S3 gateway endpoint for the current region."
  }
}
