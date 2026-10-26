locals {
  tags = var.tags
}

resource "aws_security_group" "this" {
  name        = "${var.name}-rds"
  description = "PostgreSQL access for ${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${var.name}-rds" })
}

# Standalone rules only: one rule per allowed security group. No egress is needed.
resource "aws_vpc_security_group_ingress_rule" "from_allowed" {
  count = length(var.allowed_sg_ids)

  security_group_id            = aws_security_group.this.id
  description                  = "PostgreSQL from allowed security group"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = var.allowed_sg_ids[count.index]
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-rds"
  subnet_ids = var.subnet_ids

  tags = merge(local.tags, { Name = "${var.name}-rds" })
}

# No databases are created here: the service init containers create them.
resource "aws_db_instance" "this" {
  identifier = "${var.name}-postgres"

  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t4g.small"

  storage_type      = "gp3"
  allocated_storage = 20
  storage_encrypted = true

  username = "bidnow"
  password = var.master_password

  multi_az               = var.multi_az
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  # Teardown friendly: this is a demo stack that is applied and destroyed on demand.
  deletion_protection     = false
  skip_final_snapshot     = true
  backup_retention_period = 0
  apply_immediately       = true

  tags = merge(local.tags, { Name = "${var.name}-postgres" })
}
