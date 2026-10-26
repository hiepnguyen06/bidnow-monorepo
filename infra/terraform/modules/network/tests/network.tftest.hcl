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
    condition     = length(aws_route_table_association.data) == 2
    error_message = "Each data subnet must be associated with a data route table."
  }
}

# Applied under the mock provider so route table ids are known (and distinct).
run "no_route_targets_data_route_tables" {
  command = apply

  assert {
    condition     = length(setintersection(toset([for r in aws_route.app_nat : r.route_table_id]), toset(aws_route_table.data[*].id))) == 0
    error_message = "No app default route may be attached to a data route table."
  }

  assert {
    condition     = !contains(aws_route_table.data[*].id, aws_route.public_internet.route_table_id)
    error_message = "The public default route must not be attached to a data route table."
  }

  assert {
    condition     = length(aws_route_table.data[*].id) == length(distinct(aws_route_table.data[*].id)) && length(aws_route_table.data[*].id) == 2
    error_message = "Mock ids for the data route tables must be distinct (test sanity)."
  }

  assert {
    condition     = alltrue([for r in aws_vpc_endpoint.s3.route_table_ids : !contains(aws_route_table.data[*].id, r)])
    error_message = "The S3 endpoint must only be attached to app route tables."
  }
}

run "app_routes_use_own_az_nat_when_multi_az" {
  command = apply

  variables {
    multi_az = true
  }

  assert {
    condition     = alltrue([for i in range(2) : aws_route.app_nat[i].route_table_id == aws_route_table.app[i].id])
    error_message = "Each app default route must sit in its own app route table."
  }

  assert {
    condition     = alltrue([for i in range(2) : aws_route.app_nat[i].nat_gateway_id == aws_nat_gateway.this[i].id])
    error_message = "With multi_az each app route table must use the NAT gateway with the same index."
  }

  assert {
    condition     = aws_nat_gateway.this[0].id != aws_nat_gateway.this[1].id
    error_message = "Mock ids for the NAT gateways must be distinct (test sanity)."
  }

  assert {
    condition     = alltrue([for i in range(2) : aws_nat_gateway.this[i].subnet_id == aws_subnet.public[i].id && aws_subnet.public[i].availability_zone == aws_subnet.app[i].availability_zone])
    error_message = "Each NAT must live in the public subnet of the same AZ as the app subnet it serves."
  }
}

run "app_routes_share_single_nat_when_not_multi_az" {
  command = apply

  assert {
    condition     = alltrue([for r in aws_route.app_nat : r.nat_gateway_id == aws_nat_gateway.this[0].id])
    error_message = "Without multi_az both app route tables must use the single NAT gateway."
  }

  assert {
    condition     = aws_nat_gateway.this[0].subnet_id == aws_subnet.public[0].id
    error_message = "The single NAT gateway must live in the first public subnet."
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
    condition     = aws_vpc_security_group_ingress_rule.alb_http.referenced_security_group_id == null
    error_message = "ALB ingress must not reference another security group."
  }
}

# Applied under the mock provider so security group ids are known and distinct.
run "security_group_references" {
  command = apply

  assert {
    condition     = aws_security_group.alb.id != aws_security_group.app.id
    error_message = "Mock ids for the security groups must be distinct (test sanity)."
  }

  assert {
    condition = (
      toset(keys(aws_vpc_security_group_ingress_rule.app_from_alb)) == toset(["3000", "8080"]) &&
      alltrue([for r in aws_vpc_security_group_ingress_rule.app_from_alb : r.referenced_security_group_id == aws_security_group.alb.id && r.security_group_id == aws_security_group.app.id && r.ip_protocol == "tcp" && r.cidr_ipv4 == null])
    )
    error_message = "App SG must accept TCP 3000 and 8080 only from the ALB security group."
  }

  assert {
    condition     = alltrue([for r in aws_vpc_security_group_ingress_rule.app_from_alb : r.from_port == r.to_port])
    error_message = "App ingress rules must each cover a single port."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_self.referenced_security_group_id == aws_security_group.app.id && aws_vpc_security_group_ingress_rule.app_self.security_group_id == aws_security_group.app.id
    error_message = "App SG must allow all traffic from itself (Service Connect)."
  }

  assert {
    condition = (
      toset([for r in aws_vpc_security_group_egress_rule.alb_to_app : r.from_port]) == toset([3000, 8080]) &&
      alltrue([for r in aws_vpc_security_group_egress_rule.alb_to_app : r.referenced_security_group_id == aws_security_group.app.id && r.security_group_id == aws_security_group.alb.id && r.cidr_ipv4 == null && r.from_port == r.to_port])
    )
    error_message = "ALB egress must be limited to the app security group on 3000 and 8080."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_http.security_group_id == aws_security_group.alb.id
    error_message = "ALB HTTP rule must be attached to the ALB security group."
  }
}

run "app_sg_and_s3_endpoint" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_self.ip_protocol == "-1"
    error_message = "App SG must allow all traffic from itself for Service Connect."
  }

  assert {
    condition     = aws_vpc_endpoint.s3.service_name == "com.amazonaws.ap-southeast-1.s3" && aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
    error_message = "Expected an S3 gateway endpoint for the current region."
  }
}
