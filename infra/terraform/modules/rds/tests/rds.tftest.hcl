mock_provider "aws" {}

variables {
  name            = "bidnow-test"
  vpc_id          = "vpc-123"
  subnet_ids      = ["subnet-a", "subnet-b"]
  allowed_sg_ids  = ["sg-app1", "sg-app2"]
  master_password = "test-password-123"
}

run "rds_is_not_publicly_accessible" {
  command = plan

  assert {
    condition     = aws_db_instance.this.publicly_accessible == false && aws_db_instance.this.storage_encrypted == true
    error_message = "RDS must be private and encrypted."
  }

  assert {
    condition = (
      aws_db_instance.this.engine == "postgres" &&
      aws_db_instance.this.engine_version == "15" &&
      aws_db_instance.this.instance_class == "db.t4g.small" &&
      aws_db_instance.this.storage_type == "gp3" &&
      aws_db_instance.this.allocated_storage == 20 &&
      aws_db_instance.this.username == "bidnow"
    )
    error_message = "Unexpected engine, version, class, storage or username."
  }

  assert {
    condition     = aws_db_instance.this.deletion_protection == false && aws_db_instance.this.skip_final_snapshot == true
    error_message = "RDS must be teardown friendly."
  }

  assert {
    condition     = toset(aws_db_subnet_group.this.subnet_ids) == toset(["subnet-a", "subnet-b"])
    error_message = "Subnet group must use the data subnets."
  }
}

run "rds_multi_az_follows_variable" {
  command = plan

  assert {
    condition     = aws_db_instance.this.multi_az == false
    error_message = "multi_az must default to false."
  }
}

run "rds_multi_az_true" {
  command = plan

  variables {
    multi_az = true
  }

  assert {
    condition     = aws_db_instance.this.multi_az == true
    error_message = "multi_az must follow the variable."
  }
}

run "rds_ingress_only_from_allowed_sgs" {
  command = apply

  override_resource {
    target = aws_security_group.this
    values = { id = "sg-rds" }
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.from_allowed) == 2
    error_message = "Expected one ingress rule per allowed security group."
  }

  assert {
    condition = (
      toset([for r in aws_vpc_security_group_ingress_rule.from_allowed : r.referenced_security_group_id]) == toset(["sg-app1", "sg-app2"]) &&
      alltrue([for r in aws_vpc_security_group_ingress_rule.from_allowed : r.from_port == 5432 && r.to_port == 5432 && r.ip_protocol == "tcp" && r.cidr_ipv4 == null && r.security_group_id == "sg-rds"])
    )
    error_message = "Ingress must be tcp/5432 from the allowed security groups only."
  }

  assert {
    condition     = tolist(aws_db_instance.this.vpc_security_group_ids) == tolist(["sg-rds"])
    error_message = "The instance must use the module security group."
  }
}
