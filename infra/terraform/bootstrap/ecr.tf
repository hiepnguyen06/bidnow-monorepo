locals {
  ecr_repositories = toset([
    "frontend",
    "api-gateway",
    "identity-service",
    "user-service",
    "auction-service",
    "bidding-service",
    "wallet-service",
    "media-service",
  ])
}

# Lives in bootstrap so images survive a destroy of envs/demo.
resource "aws_ecr_repository" "this" {
  for_each = local.ecr_repositories

  name                 = each.key
  image_tag_mutability = "MUTABLE" # the pipeline also moves the `latest` tag

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
