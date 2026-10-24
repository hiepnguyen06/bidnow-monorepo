# BidNow on AWS: Design

Date: 2026-10-24

## Intent and why

The owner wants to deploy the full BidNow application (Next.js web app plus the Spring Boot microservices) to AWS, defined entirely in Terraform. The purpose is **practice and a CV showcase**: reinforce AWS knowledge and show a recruiter a credible, well-structured 3-tier deployment. It is not a production launch.

The stack is brought up on demand with `terraform apply` and torn down with `terraform destroy` to keep the bill small. The landing site (`apps/landing`) is hosted separately and for free (GitHub Pages or similar) and is **not** part of this work.

## Goals

1. A 3-tier AWS architecture: presentation (CloudFront, ALB), application (ECS Fargate), data (RDS PostgreSQL, ElastiCache Redis, MSK Kafka, S3), all in Terraform.
2. Terraform that is modular and reads well on a CV: reusable modules, remote state, least-privilege IAM, no long-lived AWS keys anywhere.
3. A GitHub Actions pipeline (OIDC) that builds the images, pushes them to ECR and rolls the ECS services.
4. A cost-tuned default with a single `multi_az` switch for full high availability.
5. Documentation a recruiter can skim: an architecture diagram, how to apply and destroy, and a cost note.

## Non-goals

- A custom domain, Route 53, ACM certificates.
- WAF, SES, CloudWatch dashboards and alarms (plain log groups are included).
- Multiple environments (one `demo` environment only).
- Blue/green deployments, per-service database users, Redis TLS.
- Deploying the landing site.
- Running `terraform plan/apply` from CI. Infrastructure is applied from the owner's machine; CI only ships application images.

## Anti-goals (a failure even if it technically works)

- Long-lived AWS access keys in GitHub secrets or in code.
- Anything reachable from the internet that should be private (databases, Fargate tasks, MSK, Redis, services other than the ALB and CloudFront).
- The ALB being directly reachable, bypassing CloudFront.
- A bill that keeps running after `terraform destroy` (orphaned NAT gateways, ENIs, volumes, log groups, secrets pending deletion).
- Changing service behaviour or the public API beyond the small config changes listed under "Application changes".

## Constraints

- Region `ap-southeast-2` (Sydney), two Availability Zones. The CloudFront-scoped resources (none today, WAF later) would need a `us-east-1` provider alias.
- Compute is **ECS on Fargate only**. No EC2 instances, no ASG.
- Kafka is **Amazon MSK Provisioned** (2 brokers, `kafka.t3.small`). A 20-30 minute create time is accepted.
- No custom domain: users reach the app at `https://<id>.cloudfront.net`, and that hostname changes on every fresh apply.
- Each microservice keeps its own database (repo rule). One RDS instance hosts several databases to save cost.
- The AWS account is brand new. Fargate vCPU quotas start low (8 tasks at 0.5 vCPU need about 4 vCPU, 8 in HA mode), so the runbook must include checking and raising quotas, and confirming MSK is available, before the first apply.
- Repo conventions: conventional commits, branches `feature/<name>`, docs in `/docs` updated when architecture changes.

## Architecture (decided)

```
Browser
  |  HTTPS (default CloudFront cert)
CloudFront  --- /uploads/*          -->  S3 media bucket (private, Origin Access Control)
            --- /api/*, /ws-notifications/*, default (/)  -->  ALB (HTTP, only reachable from CloudFront)
                                                            |
                                          public subnets:   ALB, NAT gateway
                                          private app:      ECS Fargate tasks
                                          private data:     RDS, ElastiCache, MSK
```

### Tier 1: presentation
- **CloudFront** is the only public entry point. Behaviours: `/uploads/*` to the S3 origin; `/api/*` and `/ws-notifications/*` to the ALB with caching disabled and the `Authorization` header and query strings forwarded (WebSocket upgrade works through CloudFront); default behaviour to the ALB for the Next.js app, with `/_next/static/*` cached.
- **ALB** in public subnets, HTTP:80 listener only. Its security group allows ingress solely from the AWS-managed CloudFront origin-facing prefix list. CloudFront adds a secret header (`X-Origin-Verify`, a Terraform `random_password`); the listener's default action returns 403 unless the header matches. Rules: `/api/*` and `/ws-notifications/*` go to the api-gateway target group (8080); everything else goes to the frontend target group (3000).

### Tier 2: application (ECS Fargate, private app subnets)
- One ECS cluster, one **ECS Service Connect** namespace. Eight services: `frontend`, `api-gateway`, `identity-service`, `user-service`, `auction-service`, `bidding-service`, `wallet-service`, `media-service`. The `discovery-service` (Eureka) is **not** deployed; Service Connect replaces it.
- Only `frontend` and `api-gateway` attach to the ALB. The rest are internal.
- Sizing starting point: 0.5 vCPU / 1 GB per Java service (tune after first run). Target-tracking auto scaling on CPU, min 1, max 2 in demo mode. Deployment circuit breaker with rollback on.
- Images live in **ECR**, one repository per service, with a lifecycle policy keeping the last few images.
- Logs go to CloudWatch Logs, one log group per service, short retention.
- Each task has its own **task role** (least privilege). `media-service` gets read/write on the media bucket only. A shared **execution role** pulls images and reads only the secrets its task needs.
- Outbound traffic (SMTP on 587, ECR, CloudWatch) goes through the NAT gateway. An S3 gateway VPC endpoint avoids NAT charges for S3 traffic.

### Tier 3: data (isolated subnets, no route to the internet)
- **RDS PostgreSQL 15**, one `db.t4g.small` instance, single-AZ by default. Databases `identity_db`, `user_db`, `auction_db`, `bidding_db`, `wallet_db`, `media_db` live on it. Liquibase creates the schemas at service start, as today.
- **ElastiCache Redis 7**, a single `cache.t4g.micro` node, no TLS (the services connect without it today).
- **MSK Provisioned**, 2 brokers, `kafka.t3.small`, in the data subnets. TLS in transit, access restricted by security group, no client authentication. A custom MSK configuration enables topic auto-creation (the MSK default disables it).
- **S3 media bucket**, private, reachable only through CloudFront (Origin Access Control) and by `media-service`. Browser uploads use the presigned PUT URLs that `media-service` already issues, so the bucket needs a CORS rule for the CloudFront origin.
- **Secrets Manager** holds the database password, `JWT_SECRET`, the SMTP settings (`MAIL_HOST/PORT/USERNAME/PASSWORD/FROM`) and the origin-verify header value. Tasks receive them as ECS `secrets`, never as plain environment values.

### Network
- One VPC, two AZs, three subnet tiers (public, private-app, private-data). Security groups are chained tier to tier: ALB to tasks, tasks to RDS/Redis/MSK on their ports only. One NAT gateway by default.
- **`multi_az` variable** (default `false`): when `true`, adds a second NAT gateway, switches RDS to Multi-AZ, and raises task counts to 2. The two-AZ subnet layout exists in both modes because the ALB and MSK require it.

### Mail
Mail keeps working through the existing external SMTP provider, with the same five `MAIL_*` settings. The owner copies the values from their local `.env` into Secrets Manager. No AWS mail service is involved.

## Terraform layout and state

```
infra/terraform/
  bootstrap/        applied once, never destroyed: S3 state bucket, ECR repositories,
                    GitHub OIDC provider and the deploy role
  modules/          network, alb, cloudfront, ecs-cluster, ecs-service (used 8x), rds,
                    elasticache, msk, s3-media, secrets, iam
  envs/demo/        the stack that is applied and destroyed on demand
  README.md         how to bootstrap, apply, destroy, and the cost note
```

- Remote state in S3 with native locking (`use_lockfile`, no DynamoDB). Pin Terraform and provider versions.
- ECR lives in `bootstrap` so images survive a `destroy`. A fresh `apply` only needs the pipeline to have pushed images at least once.
- `envs/demo` takes an `image_tag` variable.
- Demo-friendly teardown settings: no deletion protection, `skip_final_snapshot`, `force_destroy` on the media bucket, secrets deleted without a recovery window.

## CI/CD

Replace the stubbed `.github/workflows/cd-deploy.yml` (currently an SSH deploy with `if: false`) with a workflow that:
1. Assumes the bootstrap-created IAM role via GitHub OIDC (no stored keys).
2. Builds the changed service images, tags them with the commit SHA, pushes them to ECR.
3. Runs `aws ecs update-service --force-new-deployment` for each rolled service, when the stack is up.

It is triggered manually (`workflow_dispatch`) and optionally on pushes to `main`. It must not fail just because the demo stack is torn down; pushing images must still work. A separate lightweight workflow runs `terraform fmt -check` and `terraform validate` on pull requests touching `infra/terraform`.

## Application changes (small, config-level, listed so they are not a surprise)

1. **Service discovery:** the gateway uses `lb://<service>` routes and Feign clients use Eureka names. Make the gateway route URIs and the Feign client URLs overridable by environment variables (defaulting to today's `lb://` and Eureka names), and set them to the Service Connect DNS names on AWS along with `EUREKA_CLIENT_ENABLED=false`. No Spring profile is needed. Behaviour and defaults for local development stay unchanged.
2. **Frontend URLs:** `NEXT_PUBLIC_API_URL`, `NEXT_PUBLIC_WS_URL` and `NEXT_PUBLIC_CDN_URL` are baked in at build time, but the CloudFront hostname is random per apply. The web app should use same-origin relative paths (`/api`, `/ws-notifications`, `/uploads`) so one image works under any hostname. This needs small edits to `lib/apiClient.ts`, `services/auth.service.ts`, `lib/realtime/ws-url.ts` and the CDN lookup in `lib/image-utils.ts`.
3. **Kafka TLS:** set `SPRING_KAFKA_PROPERTIES_SECURITY_PROTOCOL=SSL` through environment variables, with no code change expected. The builder should confirm the exact env variable name each service reads (`KAFKA_BOOTSTRAP_SERVERS` is used in the YAML, while compose sets `SPRING_KAFKA_BOOTSTRAP_SERVERS`).
4. **Media URLs:** `media-service` gets `CDN_BASE_URL=https://<cloudfront-domain>` as a runtime environment value from Terraform. Objects are already stored under the key prefix `uploads/` (`MediaServiceImpl.buildS3Key`), so the `/uploads/*` behaviour maps straight onto S3 keys with no rewriting.

5. **WebSocket heartbeats:** every STOMP client sets `heartbeatIncoming/Outgoing: 0` and the broker in `WebSocketConfig` has no heartbeat, so an idle connection carries no traffic and CloudFront/ALB will drop it. Enable heartbeats (around 10s) on the three client hooks and on the server's simple broker (needs a task scheduler). Live bidding and notifications are treated as required for the demo, so this change is in scope (confirmed by the owner).
6. **Notification links:** `media-service` builds absolute links in emails from `app.frontend.base-url`. Pass the CloudFront URL as `APP_FRONTEND_BASE_URL`.
7. **Images:** with relative `/uploads/...` URLs, Next's image optimizer would try to fetch from its own container and miss the CloudFront route. Either serve media images unoptimized or build absolute URLs in the browser from `window.location`. The builder picks one.

## Decisions made by the assistant (the owner has not explicitly confirmed these)

- Fargate runs `x86_64` (GitHub runners build x86 images with no extra setup; Graviton is a later optimisation).
- Images are tagged with the commit SHA and `latest`; `envs/demo` defaults `image_tag` to `latest`. First-run order is: apply `bootstrap`, push images once (by the workflow, or a documented local script), then apply `envs/demo`.
- MSK configuration: `auto.create.topics.enable=true`, `default.replication.factor=2`, `min.insync.replicas=1`, `num.partitions=3`. The services declare no `NewTopic` beans, so topics come from auto-creation.
- Terraform has no dependency cycle: CloudFront depends on the ALB and S3 only (the origin-verify header is a `random_password`), ECS services depend on CloudFront for the public URL, and the S3 bucket policy and CORS rule are separate resources that depend on the distribution.
- All eight tasks share one database user and the init containers use that same credential; the compose setup already works this way.
- The OIDC deploy role trusts `repo:hiepnguyen06/bidnow-monorepo` on `refs/heads/main` and on `workflow_dispatch` runs only.
- An AWS Budgets alert is added in `bootstrap` as a small exception to the "no alarms" non-goal. The email address is a Terraform variable.

- Service Connect instead of keeping a Eureka container (a Eureka container would be the no-code-change fallback).
- A single shared RDS instance and a single shared database user.
- Each service task includes an idempotent init container that creates its own database before the service starts, so no external step is needed to prepare RDS.
- `/_next/static/*` is served from the ALB origin and cached, not from S3. S3 is the origin for media only.
- Instance and task sizes above.
- Docs deliverables: `docs/deployment-aws.md` with an architecture diagram, plus an updated `infra/terraform/README.md` and a reference in `docs/architecture.md`.

## Left to the builder

Exact CIDR ranges, resource names and tags, CloudFront cache and origin-request policy details, health check paths and grace periods, final CPU/memory per service, the exact S3 key/prefix mapping, the idle and keep-alive settings that keep STOMP WebSocket connections open through CloudFront (origin read timeout is capped), module input/output design, and the Checkov or tflint rules to run.

## Rough cost while running (to be re-checked against current ap-southeast-2 pricing)

About $0.6 to $0.8 an hour in the default mode: Fargate tasks, a NAT gateway, the ALB, RDS, Redis and two MSK brokers. MSK is the single largest line. A 3-hour demo is therefore a few dollars. Leaving the stack running costs several hundred dollars a month.
