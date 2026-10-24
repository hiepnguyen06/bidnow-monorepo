mock_provider "aws" {}
mock_provider "random" {}

variables {
  name = "bidnow-test"
  mail = {
    host     = "smtp.example.com"
    port     = "587"
    username = "mailer"
    password = "mail-pass"
    from     = "noreply@example.com"
  }
}

run "secrets_have_zero_day_recovery" {
  command = plan

  assert {
    condition     = length(aws_secretsmanager_secret.this) == 7
    error_message = "Expected exactly seven secrets."
  }

  assert {
    condition     = alltrue([for s in aws_secretsmanager_secret.this : s.recovery_window_in_days == 0])
    error_message = "Every secret must have recovery_window_in_days = 0."
  }

  assert {
    condition     = alltrue([for k, s in aws_secretsmanager_secret.this : s.name == "bidnow-test/${replace(k, "_", "-")}"])
    error_message = "Secret names must be prefixed by var.name with dashes."
  }
}

run "jwt_secret_is_64_chars" {
  command = plan

  assert {
    condition     = random_password.jwt.length == 64
    error_message = "JWT secret must be 64 characters."
  }
}

run "generated_values_have_expected_shape" {
  command = plan

  assert {
    condition     = random_password.origin_verify.length == 32 && random_password.origin_verify.special == false
    error_message = "Origin-verify value must be 32 header-safe characters."
  }

  assert {
    condition     = random_password.db.length == 24
    error_message = "DB password must be 24 characters."
  }
}

run "db_password_has_no_rds_forbidden_chars" {
  command = plan

  # RDS forbids / " @ and space. Either no specials at all, or a set free of them.
  assert {
    condition = (
      random_password.db.special == false ||
      length(setintersection(toset(split("", random_password.db.override_special)), toset(["/", "\"", "@", " "]))) == 0
    )
    error_message = "DB password must not contain / \" @ or space."
  }
}

run "secret_arns_has_exactly_the_seven_keys" {
  command = apply

  assert {
    condition = toset(keys(output.secret_arns)) == toset([
      "db_password", "jwt_secret", "mail_host", "mail_port", "mail_username", "mail_password", "mail_from",
    ])
    error_message = "secret_arns must have exactly the seven documented keys."
  }

  assert {
    condition     = alltrue([for k, v in output.secret_arns : v == aws_secretsmanager_secret.this[k].arn])
    error_message = "secret_arns must map each key to its own secret."
  }

  assert {
    condition     = length(aws_secretsmanager_secret_version.this) == 7
    error_message = "Each secret needs a version."
  }
}

run "outputs_are_sensitive" {
  command = apply

  assert {
    condition     = issensitive(output.db_password_value) && issensitive(output.origin_verify_value)
    error_message = "db_password_value and origin_verify_value must be sensitive."
  }
}
