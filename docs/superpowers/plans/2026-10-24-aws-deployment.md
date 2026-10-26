# BidNow on AWS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy BidNow (Next.js app plus 7 Spring Boot services) to AWS as a 3-tier stack defined in Terraform, with a GitHub Actions image pipeline, applied and destroyed on demand.

**Architecture:** CloudFront fronts an ALB (app) and a private S3 bucket (uploads). ECS Fargate runs 8 services discovered through ECS Service Connect. RDS, ElastiCache and MSK sit in isolated subnets. Terraform is split into a never-destroyed `bootstrap` stack (state, ECR, OIDC role, budget) and a destroyable `envs/demo` stack built from modules.

**Tech Stack:** Terraform >= 1.10 (S3 native locking), AWS provider (pin `>= 5.82, < 7`), GitHub Actions + OIDC, Spring Boot 3.2 / Java 17, Next.js 14 / vitest, `terraform test` with mock providers.

**Spec:** `docs/superpowers/specs/2026-10-24-aws-deployment-design.md`

## Global Constraints

- Region `ap-southeast-2`, two AZs. Fargate only (no EC2, no ASG), `x86_64`.
- No custom domain, WAF, SES or dashboards. One environment (`demo`). Landing site is not deployed.
- ALB: HTTP:80 only, ingress only from the CloudFront origin-facing managed prefix list, default action 403 unless header `X-Origin-Verify` matches a `random_password`.
- Data tier (RDS, ElastiCache, MSK) lives in subnets with no route to the internet. No long-lived AWS keys anywhere.
- RDS: Postgres 15, `db.t4g.small`. Redis 7, `cache.t4g.micro`, no TLS. MSK: 2 brokers `kafka.t3.small`, TLS in transit, config `auto.create.topics.enable=true`, `default.replication.factor=2`, `min.insync.replicas=1`, `num.partitions=3`.
- Fargate: 0.5 vCPU / 1 GB per Java service as a starting size; CPU target-tracking autoscaling, min 1 / max 2; deployment circuit breaker with rollback.
- `multi_az` (default `false`) switches: second NAT gateway, RDS Multi-AZ, task counts of 2.
- Teardown-friendly: no deletion protection, `skip_final_snapshot`, S3 `force_destroy`, secrets with 0-day recovery window.
- Terraform state in S3 with `use_lockfile`; ECR repositories live in `bootstrap`; `envs/demo` takes `image_tag` (default `latest`).
- OIDC trust: `repo:hiepnguyen06/bidnow-monorepo`, ref `refs/heads/main` and `workflow_dispatch` runs only.
- Repo rules: conventional commits (`feat|fix|refactor|docs|style|test|chore`), update `/docs` when architecture changes.
- **Never commit or push without the owner's explicit permission.** Every "Checkpoint" step below means: stop, show the diff summary, ask. Never run `terraform apply` or `destroy` either; those are the owner's steps (Task 14).

## Review Focus

1. A WebSocket that sits idle for more than 60 seconds must stay connected through CloudFront and the ALB (heartbeats). Tests: Task 2.
2. A request that reaches the ALB without the correct `X-Origin-Verify` header must get 403. Tests: Task 8 and the Task 14 smoke check.
3. `terraform destroy` must leave nothing billable behind (NAT, Elastic IPs, ENIs, log groups, secrets). Check: Task 14.
4. A browser upload via the presigned PUT URL must succeed cross-origin from the CloudFront hostname (S3 CORS). Tests: Task 9.
5. A first apply with empty ECR repositories or an exhausted Fargate vCPU quota must fail with a clear message, not hang. Tests: Task 11 (precondition) and Task 13 (runbook).

---

### Task 1: Frontend works under any hostname (same-origin URLs)

**Files:**
- Modify: `apps/web/lib/apiClient.ts:4`, `apps/web/services/auth.service.ts:9`, `apps/web/lib/realtime/ws-url.ts`, `apps/web/lib/image-utils.ts`, `apps/web/next.config.ts`, `apps/web/Dockerfile`
- Test: `apps/web/lib/realtime/ws-url.test.ts` (create), `apps/web/lib/image-utils.test.ts` (extend)

**Interfaces:**
- Produces: `resolveWsEndpoint(env: { wsUrl?: string; apiUrl?: string; origin?: string }): string`. Empty/undefined `wsUrl` and an empty-string `apiUrl` with an `origin` such as `https://d1.cloudfront.net` yields `wss://d1.cloudfront.net/ws-notifications/websocket`.
- Produces: `resolveImageUrl(value)`: when `NEXT_PUBLIC_CDN_URL` is the empty string (same-origin) a bare key `uploads/a/b.jpg` returns `/uploads/a/b.jpg`; when it is `undefined` it still logs and returns `undefined`.

- [ ] **Step 1: Write failing tests** in `ws-url.test.ts`: `ws-url falls back to origin when apiUrl is empty`, `ws-url keeps explicit wsUrl`, `ws-url maps http origin to ws`; extend `image-utils.test.ts` with `resolveImageUrl returns a root-relative path when CDN url is empty string`.
- [ ] **Step 2: Run** `cd apps/web && npx vitest run lib/realtime/ws-url.test.ts lib/image-utils.test.ts`. Expected: FAIL.
- [ ] **Step 3: Implement.** In `apiClient.ts` and `auth.service.ts` change `API_URL` to `process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8080"` (nullish, so `""` means same-origin). Add the optional `origin` param to `resolveWsEndpoint`; the three socket hooks pass `window.location.origin`. In `image-utils.ts` distinguish `undefined` from `""`.
- [ ] **Step 4: Unoptimized images.** In `next.config.ts` set `images.unoptimized` when `process.env.NEXT_IMAGE_UNOPTIMIZED === 'true'` (the optimizer would otherwise fetch `/uploads/...` from the container itself). In the `Dockerfile` build stage add `ENV NEXT_PUBLIC_API_URL="" NEXT_PUBLIC_WS_URL="" NEXT_PUBLIC_CDN_URL="" NEXT_IMAGE_UNOPTIMIZED=true` and `ARG NEXT_PUBLIC_LANDING_URL` exported as env before `npm run build`.
- [ ] **Step 5: Run** `cd apps/web && npx vitest run && npm run build`. Expected: all pass, build succeeds. Local dev (`.env.example` values) must still work: leave `.env.example` unchanged.
- [ ] **Step 6: Checkpoint** (ask before committing): `feat(web): use same-origin api, websocket and media urls when env is empty`.

### Task 2: WebSocket heartbeats (client and server)

**Files:**
- Modify: `apps/web/hooks/useAuctionSocket.ts:58-59`, `apps/web/hooks/useLiveLot.ts:85-86`, `apps/web/hooks/useUserNotifications.ts:66-67`, `services/media-service/src/main/java/com/bidnow/media/config/WebSocketConfig.java`
- Test: `services/media-service/src/test/java/com/bidnow/media/config/WebSocketConfigTest.java` (create)

**Interfaces:**
- Produces: `WebSocketConfig.HEARTBEAT_MS = 10_000L`; the simple broker is registered with heartbeat `{10_000, 10_000}` and a `ThreadPoolTaskScheduler` bean named `wsHeartbeatScheduler`.

- [ ] **Step 1: Write failing test** `WebSocketConfigTest.simpleBrokerUsesTenSecondHeartbeats`: build a `MessageBrokerRegistry`, call `configureMessageBroker`, assert the broker heartbeat equals `[10000, 10000]` (read via `ReflectionTestUtils`), and `schedulerBeanIsDefined` asserts the bean exists.
- [ ] **Step 2: Run** `cd services && mvn test -pl media-service -Dtest=WebSocketConfigTest`. Expected: FAIL.
- [ ] **Step 3: Implement** the config using `registry.enableSimpleBroker(...).setHeartbeatValue(...).setTaskScheduler(...)`.
- [ ] **Step 4: Client.** Set `heartbeatIncoming` and `heartbeatOutgoing` to `10000` in the three hooks and delete the "broker has no heartbeats" comments.
- [ ] **Step 5: Run** `mvn test -pl media-service` and `cd apps/web && npx vitest run`. Expected: PASS.
- [ ] **Step 6: Checkpoint**: `fix(realtime): enable stomp heartbeats so idle sockets survive proxies`.

### Task 3: Env-driven service discovery (no Eureka on AWS)

**Files:**
- Modify: `services/api-gateway/src/main/resources/application.yml` (routes `identity-service`, `auction-service`, `user-service`, `bidding-service`, `wallet-service`, `media-service`, `media-websocket`), the 7 `@FeignClient` interfaces (`auction/feign/UserServiceClient`, `bidding/feign/{AuctionServiceClient,UserServiceClient,WalletServiceClient}`, `identity/feign/UserServiceClient`, `media/feign/{IdentityServiceClient,UserServiceClient}`)
- Test: `services/api-gateway/src/test/java/com/bidnow/gateway/RouteUrlOverrideTest.java` (create)

**Interfaces:**
- Produces: route URIs of the form `${IDENTITY_SERVICE_URL:lb://identity-service}` (same for `AUCTION_`, `USER_`, `BIDDING_`, `WALLET_`, `MEDIA_`). Feign clients use `url = "${user-service.url:}"` (and `auction-service.url`, `wallet-service.url`, `identity-service.url`); empty keeps Eureka behaviour. Services are reached at `http://<service-name>:<port>` via Service Connect; `EUREKA_CLIENT_ENABLED=false` disables registration.

- [ ] **Step 1: Write failing test** `routeUriDefaultsToEureka` (no override: `identity-service` route URI is `lb://identity-service`) and `routeUriCanBeOverridden` (property `IDENTITY_SERVICE_URL=http://identity-service:8081` gives that URI), using the existing gateway test style.
- [ ] **Step 2: Run** `cd services && mvn test -pl api-gateway -Dtest=RouteUrlOverrideTest`. Expected: FAIL.
- [ ] **Step 3: Implement** the placeholders in the gateway YAML and the `url` attribute on the 7 Feign clients. Local behaviour must be identical when the variables are unset.
- [ ] **Step 4: Run** `mvn clean install -DskipTests=false` from `services/`. Expected: BUILD SUCCESS for all modules.
- [ ] **Step 5: Checkpoint**: `feat(services): allow service urls to be overridden so eureka is optional`.

### Task 4: Terraform bootstrap stack

**Files:**
- Create: `infra/terraform/bootstrap/{versions.tf,variables.tf,state.tf,ecr.tf,github_oidc.tf,budget.tf,outputs.tf}`, `infra/terraform/bootstrap/tests/bootstrap.tftest.hcl`, `infra/terraform/.gitignore` (`.terraform/`, `*.tfstate*`, `*.tfvars` except `*.tfvars.example`)

**Interfaces:**
- Produces outputs: `state_bucket` (string), `ecr_repository_urls` (map(string) keyed by `frontend`, `api-gateway`, `identity-service`, `user-service`, `auction-service`, `bidding-service`, `wallet-service`, `media-service`), `github_deploy_role_arn` (string).
- Variables: `aws_region` (default `ap-southeast-2`), `aws_profile` (default `null`), `github_repository` (default `hiepnguyen06/bidnow-monorepo`), `budget_email` (required), `monthly_budget_usd` (default `30`).

- [ ] **Step 1: Write failing tests** in `bootstrap.tftest.hcl` (mock provider, `command = plan`): `ecr_has_eight_repos_with_lifecycle`, `state_bucket_is_versioned_and_private`, `oidc_trust_is_limited_to_main_and_dispatch` (assert the trust policy `sub` values contain only `repo:hiepnguyen06/bidnow-monorepo:ref:refs/heads/main`), `budget_has_email_subscriber`.
- [ ] **Step 2: Run** `cd infra/terraform/bootstrap && terraform init -backend=false && terraform test`. Expected: FAIL.
- [ ] **Step 3: Implement** resources. The deploy role permits only ECR push to those repositories and `ecs:UpdateService`/`DescribeClusters`/`DescribeServices` on cluster `bidnow-demo`. Bootstrap itself uses a local backend (state file kept by the owner).
- [ ] **Step 4: Run** `terraform fmt -check -recursive && terraform validate && terraform test`. Expected: all pass.
- [ ] **Step 5: Checkpoint**: `feat(infra): add terraform bootstrap stack for state, ecr, oidc and budget`.

### Task 5: Network module

**Files:**
- Create: `infra/terraform/modules/network/{main.tf,variables.tf,outputs.tf,tests/network.tftest.hcl}`

**Interfaces:**
- Inputs: `name` (string), `azs` (list(string), 2), `multi_az` (bool, default false), `vpc_cidr` (default `10.0.0.0/16`).
- Subnets: public `10.0.0.0/24`, `10.0.1.0/24`; app `10.0.10.0/24`, `10.0.11.0/24`; data `10.0.20.0/24`, `10.0.21.0/24`.
- Outputs: `vpc_id`, `public_subnet_ids`, `app_subnet_ids`, `data_subnet_ids`, `alb_sg_id`, `app_sg_id`. `alb_sg_id` allows port 80 from the managed prefix list `com.amazonaws.global.cloudfront.origin-facing`; `app_sg_id` allows 3000 and 8080 from `alb_sg_id`, and all traffic from itself (Service Connect). Includes an S3 gateway endpoint on the app route tables.

- [ ] **Step 1: Write failing tests**: `single_nat_by_default` (1 NAT gateway), `two_nats_when_multi_az` (2), `data_route_tables_have_no_default_route`, `alb_sg_ingress_is_prefix_list_only` (no cidr_blocks on ingress).
- [ ] **Step 2: Run** `cd infra/terraform/modules/network && terraform init -backend=false && terraform test`. Expected: FAIL.
- [ ] **Step 3: Implement** VPC, subnets, IGW, NAT(s) with EIPs, route tables, security groups, S3 endpoint.
- [ ] **Step 4: Run** `terraform fmt -check && terraform validate && terraform test`. Expected: PASS.
- [ ] **Step 5: Checkpoint**: `feat(infra): add network module`.

### Task 6: Data modules (rds, elasticache, msk)

**Files:**
- Create: `infra/terraform/modules/{rds,elasticache,msk}/{main.tf,variables.tf,outputs.tf,tests/*.tftest.hcl}`

**Interfaces:**
- Common inputs: `name`, `vpc_id`, `subnet_ids` (data subnets), `allowed_sg_ids` (list(string); pass `[app_sg_id]`).
- `rds` inputs add `multi_az` (bool), `master_password` (string, sensitive); outputs `address`, `port`, `master_username` (`bidnow`). Parameter group creates none of the databases.
- `elasticache` outputs `address`, `port`.
- `msk` outputs `bootstrap_brokers_tls`, `cluster_arn`. Includes `aws_msk_configuration` with the Global Constraints values.

- [ ] **Step 1: Write failing tests**: `rds_is_not_publicly_accessible`, `rds_multi_az_follows_variable`, `rds_ingress_only_from_allowed_sgs`, `redis_single_node_no_transit_encryption`, `msk_two_brokers_tls_only`, `msk_config_enables_topic_autocreate`, `msk_replication_factor_two`.
- [ ] **Step 2: Run** `terraform test` in each module directory. Expected: FAIL.
- [ ] **Step 3: Implement** each module, applying the teardown settings from Global Constraints.
- [ ] **Step 4: Run** `terraform fmt -check -recursive && terraform validate && terraform test` per module. Expected: PASS.
- [ ] **Step 5: Checkpoint**: `feat(infra): add rds, elasticache and msk modules`.

### Task 7: Secrets and media-bucket modules

**Files:**
- Create: `infra/terraform/modules/secrets/*`, `infra/terraform/modules/s3-media/*` (each with `tests/`)

**Interfaces:**
- `secrets` inputs: `name`, `mail` (object `{host, port, username, password, from}`, sensitive). Creates `random_password`s for DB, JWT (64 chars) and origin-verify header. Outputs: `secret_arns` (map keyed `db_password`, `jwt_secret`, `mail_host`, `mail_port`, `mail_username`, `mail_password`, `mail_from`), `db_password_value` and `origin_verify_value` (sensitive strings). Each mail field is its own secret so ECS can map it to one env var.
- `s3-media` inputs: `name`. The task-role access policy is built in Task 11, not here. Outputs: `bucket_id`, `bucket_arn`, `bucket_regional_domain_name`. Bucket is private, blocks all public access, `force_destroy = true`.

- [ ] **Step 1: Write failing tests**: `secrets_have_zero_day_recovery`, `jwt_secret_is_64_chars`, `bucket_blocks_public_access`, `bucket_force_destroy_enabled`.
- [ ] **Step 2: Run** `terraform test` in each module. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** fmt/validate/test. Expected: PASS.
- [ ] **Step 5: Checkpoint**: `feat(infra): add secrets and s3-media modules`.

### Task 8: ALB module

**Files:**
- Create: `infra/terraform/modules/alb/*` (with `tests/alb.tftest.hcl`)

**Interfaces:**
- Inputs: `name`, `vpc_id`, `public_subnet_ids`, `alb_sg_id`, `origin_verify_value` (sensitive).
- Outputs: `dns_name`, `frontend_target_group_arn` (port 3000, health path `/`), `gateway_target_group_arn` (port 8080, health path `/actuator/health`), both target type `ip`.
- Listener HTTP:80: default action fixed response 403; rules (priority 10 gateway for `/api/*` and `/ws-notifications/*`, priority 20 frontend for `/*`) each require header `X-Origin-Verify` equal to the value.

- [ ] **Step 1: Write failing tests**: `listener_default_action_is_403`, `every_forward_rule_requires_origin_header`, `gateway_rule_matches_api_and_ws_paths`, `gateway_health_check_path`.
- [ ] **Step 2: Run** `terraform test`. Expected: FAIL.
- [ ] **Step 3: Implement.** Set idle timeout to 120 seconds.
- [ ] **Step 4: Run** fmt/validate/test. Expected: PASS.
- [ ] **Step 5: Checkpoint**: `feat(infra): add alb module with origin-verify header rules`.

### Task 9: CloudFront module

**Files:**
- Create: `infra/terraform/modules/cloudfront/*` (with `tests/`)

**Interfaces:**
- Inputs: `name`, `alb_dns_name`, `origin_verify_value` (sensitive), `media_bucket_id`, `media_bucket_arn`, `media_bucket_regional_domain_name`.
- Outputs: `domain_name`, `distribution_arn`.
- Origins: ALB (`http-only`, custom header `X-Origin-Verify`) and S3 with Origin Access Control. Behaviours, in order: `/uploads/*` (S3, managed CachingOptimized, GET/HEAD/OPTIONS), `/api/*` and `/ws-notifications/*` (ALB, managed CachingDisabled, origin request policy AllViewerExceptHostHeader, all HTTP methods), `/_next/static/*` (ALB, CachingOptimized), default (ALB, CachingDisabled, AllViewerExceptHostHeader, all methods). Viewer protocol: redirect to HTTPS. Also creates `aws_s3_bucket_policy` (OAC read for this distribution only) and `aws_s3_bucket_cors_configuration` allowing `PUT`, `GET`, `HEAD` from `https://<domain_name>` with all headers.

- [ ] **Step 1: Write failing tests**: `uploads_behavior_targets_s3`, `api_and_ws_behaviors_not_cached`, `alb_origin_sends_verify_header`, `bucket_policy_allows_only_this_distribution`, `cors_allows_put_from_distribution_domain` (Review Focus 4).
- [ ] **Step 2: Run** `terraform test`. Expected: FAIL.
- [ ] **Step 3: Implement.** Use the default CloudFront certificate and price class `PriceClass_100`.
- [ ] **Step 4: Run** fmt/validate/test. Expected: PASS.
- [ ] **Step 5: Checkpoint**: `feat(infra): add cloudfront module with alb and s3 origins`.

### Task 10: ECS cluster and service modules

**Files:**
- Create: `infra/terraform/modules/ecs-cluster/*`, `infra/terraform/modules/ecs-service/*` (each with `tests/`)

**Interfaces:**
- `ecs-cluster` inputs `name`; outputs `cluster_arn`, `cluster_name` (`bidnow-demo`), `namespace_arn` (Service Connect namespace `bidnow.local`), `execution_role_arn`. The execution role gets ECR pull, log writes, and `secretsmanager:GetSecretValue` on the ARNs passed in `secret_arns` (input, list(string)).
- `ecs-service` inputs: `name`, `cluster_arn`, `namespace_arn`, `execution_role_arn`, `image` (string), `port` (number), `cpu` (default 512), `memory` (default 1024), `desired_count`, `min_count`, `max_count`, `subnet_ids`, `security_group_ids`, `env` (map(string)), `secrets` (map(string): env var name to secret ARN), `target_group_arn` (string, default null), `init_database` (string, default null), `db_host`, `db_user`, `db_password_secret_arn`, `task_policy_json` (string, default null), `log_retention_days` (default 7).
- Outputs: `service_name`, `task_role_arn`.
- Behaviour: Service Connect publishes `name:port`; log group `/ecs/<name>`; when `init_database` is set, a non-essential `postgres:15-alpine` container creates the database if missing (`SELECT ... \gexec` idempotent pattern) and the main container depends on it with condition `SUCCESS`; autoscaling target tracking CPU 60%; `deployment_circuit_breaker { enable, rollback }`; `runtime_platform` `X86_64`/`LINUX`; no container-level health check command (alpine JRE has no curl).

- [ ] **Step 1: Write failing tests** (`ecs-service`): `init_container_present_only_when_database_set`, `main_container_waits_for_init_success`, `secrets_are_not_plain_env`, `circuit_breaker_rollback_enabled`, `autoscaling_target_is_cpu_60`, `platform_is_x86_64`, `task_role_has_only_given_policy`.
- [ ] **Step 2: Run** `terraform test` in both modules. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** fmt/validate/test. Expected: PASS.
- [ ] **Step 5: Checkpoint**: `feat(infra): add ecs cluster and reusable ecs-service modules`.

### Task 11: `envs/demo` wiring

**Files:**
- Create: `infra/terraform/envs/demo/{versions.tf,backend.tf,variables.tf,main.tf,services.tf,outputs.tf,terraform.tfvars.example,tests/demo.tftest.hcl}`

**Interfaces:**
- Variables: `aws_region`, `aws_profile`, `multi_az` (false), `image_tag` ("latest"), `ecr_repository_urls` (map(string), from bootstrap output), `mail` (sensitive object as in Task 7).
- `services.tf` defines `local.services`, a map keyed by service name with `port`, `database`, and `env`. Ports: frontend 3000, api-gateway 8080, identity 8081, user 8082, auction 8083, bidding 8084, wallet 8085, media 8086. Databases: `identity_db`, `user_db`, `auction_db`, `bidding_db`, `wallet_db`, `media_db`. Only `frontend` and `api-gateway` receive target groups; the Next.js and gateway services have no database.
- Env mapping per Global Constraints and spec: all Java services get `EUREKA_CLIENT_ENABLED=false`, `KAFKA_BOOTSTRAP_SERVERS` and `SPRING_KAFKA_BOOTSTRAP_SERVERS` (both set to the MSK TLS brokers), `SPRING_KAFKA_PROPERTIES_SECURITY_PROTOCOL=SSL`, `DB_URL=jdbc:postgresql://<rds>:5432/<database>`, `DB_USERNAME`, secret `DB_PASSWORD`; `REDIS_HOST` for auction, bidding, media; secret `JWT_SECRET` for api-gateway and identity; the gateway also gets `IDENTITY_SERVICE_URL=http://identity-service:8081` and so on for the other five; services with Feign clients get `USER_SERVICE_URL`, `AUCTION_SERVICE_URL`, `WALLET_SERVICE_URL`, `IDENTITY_SERVICE_URL` using the property names from Task 3; media gets `AWS_REGION`, `AWS_BUCKET_NAME`, `CDN_BASE_URL=https://<cloudfront domain>`, `APP_FRONTEND_BASE_URL=https://<cloudfront domain>` and the five `MAIL_*` secrets, plus a task policy allowing `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject` on the media bucket only.
- `terraform_data` precondition: every URL in `ecr_repository_urls` must have an image with `image_tag` (via `data "aws_ecr_image"`), failing with the message "Push images first: see docs/deployment-aws.md" (Review Focus 5).

- [ ] **Step 1: Write failing tests**: `eight_services_defined`, `only_frontend_and_gateway_have_target_groups`, `bidding_service_has_redis_host`, `no_secret_values_in_plain_env`, `multi_az_true_sets_task_count_two`, `media_service_task_policy_scoped_to_bucket`.
- [ ] **Step 2: Run** `cd infra/terraform/envs/demo && terraform init -backend=false && terraform test`. Expected: FAIL.
- [ ] **Step 3: Implement** the root module wiring all modules. Backend values come from `-backend-config` flags documented in the README (bucket from bootstrap output).
- [ ] **Step 4: Run** `terraform fmt -check -recursive ../.. && terraform validate && terraform test`. Expected: PASS.
- [ ] **Step 5: Checkpoint**: `feat(infra): add demo environment wiring all modules`.

### Task 12: CI/CD workflows

**Files:**
- Modify: `.github/workflows/cd-deploy.yml` (replace contents; rename the workflow `Deploy to AWS`)
- Create: `.github/workflows/terraform-validate.yml`

**Interfaces:**
- Consumes repo variables `AWS_DEPLOY_ROLE_ARN`, `AWS_REGION` (`ap-southeast-2`), `LANDING_URL`.
- `cd-deploy.yml`: triggers `workflow_dispatch` with an optional `services` input (default `all`) and `push` to `main` on paths `services/**`, `apps/web/**`. Permissions `id-token: write`, `contents: read`. Matrix over the 8 images (no `discovery-service`); build with `docker/build-push-action` using context `services` and file `services/<name>/Dockerfile` (frontend: context `apps/web`, build-arg `NEXT_PUBLIC_LANDING_URL`); tags `<repo-url>:<sha>` and `:latest`; then, only if cluster `bidnow-demo` is `ACTIVE`, `aws ecs update-service --force-new-deployment`. A torn-down cluster must not fail the run.
- `terraform-validate.yml`: on PRs touching `infra/terraform/**`, runs `terraform fmt -check -recursive`, then `init -backend=false`, `validate` and `test` for `bootstrap`, each module, and `envs/demo`.

- [ ] **Step 1: Write the workflows.**
- [ ] **Step 2: Lint** with `actionlint` (install via `go install` or the release binary into the scratchpad). Expected: no errors.
- [ ] **Step 3: Confirm** the YAML has no `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` references (`grep -rn "ACCESS_KEY" .github/workflows` returns nothing).
- [ ] **Step 4: Checkpoint**: `feat(ci): add oidc-based aws deploy and terraform validate workflows`.

### Task 13: Documentation and runbook

**Files:**
- Create: `docs/deployment-aws.md`, `docs/diagrams/08-aws-deployment.md` (Mermaid diagram of the three tiers)
- Modify: `infra/terraform/README.md`, `docs/architecture.md` (link to the AWS section), `services/CLAUDE.md` (env table: new override variables)

**Interfaces:**
- `deployment-aws.md` must contain, in order: architecture diagram, cost note (about $0.6 to $0.8 an hour), **prerequisites** (check Fargate on-demand vCPU quota is at least 8 and request an increase; confirm MSK is available; AWS CLI profile), **first-run order** (bootstrap apply, set GitHub repo variables, run the Deploy workflow once, apply `envs/demo`), **smoke checks** (Task 14), **destroy and orphan check** commands, and a troubleshooting section for quota errors and empty ECR.

- [ ] **Step 1: Write the docs.** Every command in the runbook must be copy-pasteable.
- [ ] **Step 2: Verify** links with `grep -rn "deployment-aws" docs infra services`; each referenced path exists.
- [ ] **Step 3: Checkpoint**: `docs(infra): add aws deployment guide and runbook`.

### Task 14: Owner-run verification (no agent apply or destroy)

**Files:** none. This task is a checklist the owner executes with the Task 13 runbook; the agent only prepares the commands and reads the owner's results.

- [ ] **Step 1:** Owner runs bootstrap apply, sets repo variables, runs the Deploy workflow, then `terraform apply` in `envs/demo` (expect 25 to 35 minutes, dominated by MSK).
- [ ] **Step 2: Smoke checks.** `curl -i http://<alb-dns>/` returns 403 (Review Focus 2). `curl -i https://<cloudfront-domain>/` returns 200. Register and log in. Upload an image (presigned PUT works cross-origin, Review Focus 4). Place a bid in two browsers and see the live update. Leave a socket idle for 90 seconds and confirm it still receives a bid (Review Focus 1). Trigger an email and confirm it arrives.
- [ ] **Step 3: Destroy and orphan check.** Owner runs `terraform destroy` in `envs/demo`, then the runbook commands listing NAT gateways, Elastic IPs, network interfaces, log groups prefixed `/ecs/` and secrets in the account. Expected: none left from this stack (Review Focus 3).
- [ ] **Step 4:** Record what was wrong in the runbook and fix the plan/docs. Ask before committing.
