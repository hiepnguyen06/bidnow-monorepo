# Partial S3 backend configuration with native S3 locking (no DynamoDB table).
# The values are supplied at init time so no account-specific name is committed:
#
#   terraform init \
#     -backend-config="bucket=$(terraform -chdir=../../bootstrap output -raw state_bucket)" \
#     -backend-config="key=envs/demo/terraform.tfstate" \
#     -backend-config="region=ap-southeast-2"
#
# Add -backend-config="profile=<aws-profile>" when using a named AWS CLI profile.
# Tests and CI run `terraform init -backend=false` and never touch the backend.
terraform {
  backend "s3" {
    use_lockfile = true
  }
}
