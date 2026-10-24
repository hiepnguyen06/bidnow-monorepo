mock_provider "aws" {}

variables {
  name = "bidnow-test"
}

run "bucket_blocks_public_access" {
  command = plan

  assert {
    condition = (
      aws_s3_bucket_public_access_block.this.block_public_acls == true &&
      aws_s3_bucket_public_access_block.this.block_public_policy == true &&
      aws_s3_bucket_public_access_block.this.ignore_public_acls == true &&
      aws_s3_bucket_public_access_block.this.restrict_public_buckets == true
    )
    error_message = "All four public access block settings must be true."
  }

  assert {
    condition     = aws_s3_bucket_ownership_controls.this.rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "Ownership must be BucketOwnerEnforced."
  }
}

run "bucket_force_destroy_enabled" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.force_destroy == true && aws_s3_bucket.this.bucket_prefix == "bidnow-test-media-"
    error_message = "Bucket must be force-destroyable and use the media prefix."
  }
}

run "bucket_is_encrypted" {
  command = plan

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "Bucket must use AES256 server-side encryption."
  }
}

run "settings_and_outputs_reference_the_bucket" {
  command = apply

  override_resource {
    target = aws_s3_bucket.this
    values = {
      id                          = "bidnow-test-media-123"
      arn                         = "arn:aws:s3:::bidnow-test-media-123"
      bucket_regional_domain_name = "bidnow-test-media-123.s3.us-east-1.amazonaws.com"
    }
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.this.bucket == "bidnow-test-media-123" &&
      aws_s3_bucket_ownership_controls.this.bucket == "bidnow-test-media-123" &&
      aws_s3_bucket_server_side_encryption_configuration.this.bucket == "bidnow-test-media-123"
    )
    error_message = "All bucket settings must reference the bucket."
  }

  assert {
    condition = (
      output.bucket_id == "bidnow-test-media-123" &&
      output.bucket_arn == "arn:aws:s3:::bidnow-test-media-123" &&
      output.bucket_regional_domain_name == "bidnow-test-media-123.s3.us-east-1.amazonaws.com"
    )
    error_message = "Outputs must expose the bucket attributes."
  }
}
