# Resolves com.amazonaws.<region>.s3 for the provider's region without relying on
# data.aws_region attributes (renamed/deprecated between provider 5.x and 6.x).
data "aws_vpc_endpoint_service" "s3" {
  service      = "s3"
  service_type = "Gateway"
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

locals {
  public_cidrs = ["10.0.0.0/24", "10.0.1.0/24"]
  app_cidrs    = ["10.0.10.0/24", "10.0.11.0/24"]
  data_cidrs   = ["10.0.20.0/24", "10.0.21.0/24"]

  nat_count = var.multi_az ? 2 : 1
  tags      = var.tags
}

# ---------------------------------------------------------------------------
# VPC, subnets, internet gateway
# ---------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { Name = var.name })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.azs[count.index]
  cidr_block              = local.public_cidrs[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.tags, { Name = "${var.name}-public-${count.index + 1}", Tier = "public" })
}

resource "aws_subnet" "app" {
  count = 2

  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = local.app_cidrs[count.index]

  tags = merge(local.tags, { Name = "${var.name}-app-${count.index + 1}", Tier = "app" })
}

resource "aws_subnet" "data" {
  count = 2

  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = local.data_cidrs[count.index]

  tags = merge(local.tags, { Name = "${var.name}-data-${count.index + 1}", Tier = "data" })
}

# ---------------------------------------------------------------------------
# NAT gateway(s): one in the first public subnet, or one per AZ when multi_az
# ---------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count = local.nat_count

  domain = "vpc"

  tags = merge(local.tags, { Name = "${var.name}-nat-${count.index + 1}" })
}

resource "aws_nat_gateway" "this" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.tags, { Name = "${var.name}-nat-${count.index + 1}" })

  depends_on = [aws_internet_gateway.this]
}

# ---------------------------------------------------------------------------
# Route tables
# ---------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app" {
  count = 2

  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, { Name = "${var.name}-app-${count.index + 1}" })
}

# Each app subnet uses the NAT in its own AZ when multi_az, else the single NAT.
resource "aws_route" "app_nat" {
  count = 2

  route_table_id         = aws_route_table.app[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.multi_az ? count.index : 0].id
}

resource "aws_route_table_association" "app" {
  count = 2

  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

# Data tier is isolated: local VPC routing only, no default route.
resource "aws_route_table" "data" {
  count = 2

  vpc_id = aws_vpc.this.id

  # Explicitly empty: Terraform will remove any route added out of band.
  route = []

  tags = merge(local.tags, { Name = "${var.name}-data-${count.index + 1}" })
}

resource "aws_route_table_association" "data" {
  count = 2

  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data[count.index].id
}

# ---------------------------------------------------------------------------
# S3 gateway endpoint (keeps ECR layer pulls off the NAT)
# ---------------------------------------------------------------------------

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = data.aws_vpc_endpoint_service.s3.service_name
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.app[*].id

  tags = merge(local.tags, { Name = "${var.name}-s3" })
}

# ---------------------------------------------------------------------------
# Security groups
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "ALB: HTTP from CloudFront origin-facing addresses only"
  vpc_id      = aws_vpc.this.id

  # Rules live in separate aws_vpc_security_group_*_rule resources; empty inline
  # lists make Terraform drop anything added out of band.
  ingress = []
  egress  = []

  tags = merge(local.tags, { Name = "${var.name}-alb" })
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "ECS tasks: traffic from the ALB and from other tasks"
  vpc_id      = aws_vpc.this.id

  ingress = []
  egress  = []

  tags = merge(local.tags, { Name = "${var.name}-app" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from CloudFront origin-facing prefix list"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id

  tags = merge(local.tags, { Name = "${var.name}-alb-http" })
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  for_each = toset(["3000", "8080"])

  security_group_id            = aws_security_group.alb.id
  description                  = "To app tasks on ${each.value}"
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.app.id

  tags = merge(local.tags, { Name = "${var.name}-alb-to-app-${each.value}" })
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  for_each = toset(["3000", "8080"])

  security_group_id            = aws_security_group.app.id
  description                  = "From ALB on ${each.value}"
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.alb.id

  tags = merge(local.tags, { Name = "${var.name}-app-from-alb-${each.value}" })
}

resource "aws_vpc_security_group_ingress_rule" "app_self" {
  security_group_id            = aws_security_group.app.id
  description                  = "All traffic between tasks (Service Connect)"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.app.id

  tags = merge(local.tags, { Name = "${var.name}-app-self" })
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(local.tags, { Name = "${var.name}-app-egress" })
}
