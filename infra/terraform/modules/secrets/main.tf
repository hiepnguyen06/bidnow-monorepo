locals {
  tags = var.tags
}

# special = false keeps every generated value safe for RDS (which forbids / " @ and space),
# HTTP headers and env vars.
resource "random_password" "db" {
  length  = 24
  special = false
}

resource "random_password" "jwt" {
  length  = 64
  special = false
}

# Not stored in Secrets Manager: passed to the ALB and CloudFront as a Terraform value only.
resource "random_password" "origin_verify" {
  length  = 32
  special = false
}

locals {
  # One secret per value so ECS can map each one to a single environment variable.
  secret_values = {
    db_password   = random_password.db.result
    jwt_secret    = random_password.jwt.result
    mail_host     = var.mail.host
    mail_port     = var.mail.port
    mail_username = var.mail.username
    mail_password = var.mail.password
    mail_from     = var.mail.from
  }
  secret_keys = toset([
    "db_password",
    "jwt_secret",
    "mail_host",
    "mail_port",
    "mail_username",
    "mail_password",
    "mail_from",
  ])
}

resource "aws_secretsmanager_secret" "this" {
  for_each = local.secret_keys

  name = "${var.name}/${replace(each.key, "_", "-")}"

  # Teardown friendly: allows the same name to be recreated straight after destroy.
  recovery_window_in_days = 0

  tags = merge(local.tags, { Name = "${var.name}/${replace(each.key, "_", "-")}" })
}

resource "aws_secretsmanager_secret_version" "this" {
  for_each = local.secret_keys

  secret_id     = aws_secretsmanager_secret.this[each.key].id
  secret_string = local.secret_values[each.key]
}
