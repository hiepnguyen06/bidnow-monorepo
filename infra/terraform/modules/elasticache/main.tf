locals {
  tags = var.tags
}

resource "aws_security_group" "this" {
  name        = "${var.name}-redis"
  description = "Redis access for ${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${var.name}-redis" })
}

# Standalone rules only: one rule per allowed security group. No egress is needed.
resource "aws_vpc_security_group_ingress_rule" "from_allowed" {
  count = length(var.allowed_sg_ids)

  security_group_id            = aws_security_group.this.id
  description                  = "Redis from allowed security group"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = var.allowed_sg_ids[count.index]
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-redis"
  subnet_ids = var.subnet_ids

  tags = merge(local.tags, { Name = "${var.name}-redis" })
}

# A replication group with one node is the simplest single-node Redis resource
# that exposes a stable primary endpoint address.
resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name}-redis"
  description          = "Redis for ${var.name}"

  engine               = "redis"
  engine_version       = "7.1"
  node_type            = "cache.t4g.micro"
  port                 = 6379
  parameter_group_name = "default.redis7"

  num_cache_clusters         = 1
  automatic_failover_enabled = false
  multi_az_enabled           = false

  transit_encryption_enabled = false
  at_rest_encryption_enabled = true

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.this.id]

  apply_immediately = true

  tags = merge(local.tags, { Name = "${var.name}-redis" })
}
