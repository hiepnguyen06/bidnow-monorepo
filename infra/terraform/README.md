# Terraform

AWS infrastructure of BidNow (ECS Fargate, RDS, ElastiCache, MSK, S3, CloudFront), region `ap-southeast-2`. The full runbook (prerequisites, first-run order, smoke checks, destroy and orphan check, troubleshooting) is in [docs/deployment-aws.md](../../docs/deployment-aws.md); the architecture diagram is in [docs/diagrams/09-aws-deployment.md](../../docs/diagrams/09-aws-deployment.md). Local development infrastructure (Postgres, Redis, Kafka) lives in [`../local`](../local).

## Layout

| Path | Purpose |
|------|---------|
| `bootstrap/` | Applied once, never destroyed. Owns the S3 state bucket, 8 ECR repositories, the GitHub OIDC provider with the deploy role, and the AWS Budget alert. Local backend. |
| `modules/` | Reusable modules: `network`, `alb`, `cloudfront`, `ecs-cluster`, `ecs-service` (used for each of the 8 services), `ecs-service-tier` (creates one tier of services; `envs/demo` chains five of them so servers exist before their clients), `rds`, `elasticache`, `msk`, `s3-media`, `secrets`. |
| `envs/demo/` | The stack that is applied and destroyed on demand. Wires all modules together. Remote state in the bootstrap bucket (S3 backend with `use_lockfile`). Needs Terraform >= 1.10 and the aws provider >= 6.5. |

Typical flow: apply `bootstrap`, push images to ECR, `terraform init -backend-config=...` and apply `envs/demo`, then destroy it when finished. Exact commands are in the runbook.

## Running the tests

The tests use mock providers only: no AWS credentials and no network access to AWS are needed.

The configurations need Terraform >= 1.10, but the **tests need a newer Terraform**: they were written and run with **1.16.6**, and the `terraform-validate` workflow pins exactly that version. They use `state_key` in `run` blocks and boolean expressions that rely on short-circuit evaluation; Terraform 1.10 rejects the first and fails on the second.

```bash
cd infra/terraform
terraform fmt -check -recursive

# per root or module directory, for example:
cd envs/demo
terraform init -backend=false
terraform validate
terraform test
```

Repeat `init -backend=false`, `validate` and `terraform test` in `bootstrap/` and in each `modules/<name>/` that has a `tests/` directory. The `terraform-validate` GitHub workflow runs the same checks on pull requests that touch `infra/terraform`.

## Apply and destroy are manual

`terraform apply` and `terraform destroy` are run by hand from the owner's machine. No pipeline applies or destroys infrastructure; CI only validates Terraform and ships application images (the `Deploy to AWS` workflow). While `envs/demo` is applied it costs roughly $0.6 to $0.8 per hour, so destroy it when done.
