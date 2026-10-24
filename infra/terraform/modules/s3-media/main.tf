locals {
  tags = var.tags
}

# Bucket policy and CORS live in the cloudfront module because they depend on the distribution.
resource "aws_s3_bucket" "this" {
  bucket_prefix = "${var.name}-media-"

  # Teardown friendly: demo media is disposable.
  force_destroy = true

  tags = merge(local.tags, { Name = "${var.name}-media" })
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
