mock_provider "aws" {}

variables {
  name           = "bidnow-test"
  vpc_id         = "vpc-123"
  subnet_ids     = ["subnet-a", "subnet-b"]
  allowed_sg_ids = ["sg-app1"]
}

run "redis_single_node_no_transit_encryption" {
  command = apply

  override_resource {
    target = aws_security_group.this
    values = { id = "sg-redis" }
  }

  assert {
    condition = (
      aws_elasticache_replication_group.this.engine == "redis" &&
      startswith(aws_elasticache_replication_group.this.engine_version, "7") &&
      aws_elasticache_replication_group.this.node_type == "cache.t4g.micro" &&
      aws_elasticache_replication_group.this.num_cache_clusters == 1 &&
      aws_elasticache_replication_group.this.automatic_failover_enabled == false
    )
    error_message = "Expected a single Redis 7 cache.t4g.micro node without failover."
  }

  assert {
    condition     = aws_elasticache_replication_group.this.transit_encryption_enabled == false
    error_message = "Transit encryption must be off (services connect without TLS)."
  }

  assert {
    condition     = tolist(aws_elasticache_replication_group.this.security_group_ids) == tolist(["sg-redis"])
    error_message = "Replication group must use the module security group."
  }
}

run "redis_ingress_only_from_allowed_sgs" {
  command = apply

  override_resource {
    target = aws_security_group.this
    values = { id = "sg-redis" }
  }

  assert {
    condition = (
      length(aws_vpc_security_group_ingress_rule.from_allowed) == 1 &&
      alltrue([for r in aws_vpc_security_group_ingress_rule.from_allowed : r.referenced_security_group_id == "sg-app1" && r.from_port == 6379 && r.to_port == 6379 && r.ip_protocol == "tcp" && r.security_group_id == "sg-redis"])
    )
    error_message = "Ingress must be tcp/6379 from the allowed security group only."
  }

  assert {
    condition     = toset(aws_elasticache_subnet_group.this.subnet_ids) == toset(["subnet-a", "subnet-b"])
    error_message = "Subnet group must use the data subnets."
  }
}
