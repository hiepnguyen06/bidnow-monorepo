# AWS Deployment Architecture

Three-tier layout of the `envs/demo` Terraform stack in `ap-southeast-2`. CloudFront is the only public entry point; the ALB accepts traffic only from CloudFront (security group on the managed prefix list plus the secret `X-Origin-Verify` header). Fargate tasks, RDS, ElastiCache and MSK have no public addresses. The `bootstrap` stack (state bucket, ECR, GitHub OIDC role, budget) is applied once and never destroyed. See [deployment-aws.md](../deployment-aws.md) for the runbook.

```mermaid
flowchart TB
    User([Browser])

    subgraph Edge["Tier 1: presentation"]
        CF["CloudFront<br/>default *.cloudfront.net certificate"]
        ALB["Application Load Balancer<br/>HTTP:80, 403 without X-Origin-Verify"]
    end

    subgraph App["Tier 2: application (private app subnets, ECS Fargate)"]
        direction LR
        FE["frontend :3000"]
        GW["api-gateway :8080"]
        subgraph SC["ECS Service Connect namespace bidnow.local"]
            direction LR
            ID["identity-service :8081"]
            US["user-service :8082"]
            AU["auction-service :8083"]
            BI["bidding-service :8084"]
            WA["wallet-service :8085"]
            ME["media-service :8086"]
        end
    end

    subgraph Data["Tier 3: data (isolated subnets, no internet route)"]
        direction LR
        RDS[("RDS PostgreSQL 15<br/>one database per service")]
        REDIS[("ElastiCache Redis 7")]
        MSK[["MSK Kafka<br/>2 brokers, TLS"]]
    end

    S3[("S3 media bucket<br/>private, Origin Access Control")]
    SM["Secrets Manager<br/>DB password, JWT, SMTP, origin header"]
    NAT["NAT gateway<br/>SMTP, ECR, CloudWatch"]

    subgraph Boot["bootstrap stack (never destroyed)"]
        direction LR
        ECR["ECR<br/>8 repositories"]
        STATE[("S3 Terraform state")]
        OIDC["IAM OIDC provider<br/>+ deploy role"]
    end

    GHA["GitHub Actions<br/>Deploy to AWS"]
    SMTP["External SMTP provider"]

    User -->|HTTPS| CF
    CF -->|"/uploads/*"| S3
    CF -->|"/api/*, /ws-notifications/*<br/>no cache, WebSocket upgrade"| ALB
    CF -->|"default, /_next/static/* cached"| ALB
    ALB -->|"/api/*, /ws-notifications/*"| GW
    ALB -->|"everything else"| FE

    GW --> ID
    GW --> US
    GW --> AU
    GW --> BI
    GW --> WA
    GW --> ME
    BI -.->|Feign| WA
    BI -.->|Feign| AU

    ID --> RDS
    US --> RDS
    AU --> RDS
    BI --> RDS
    WA --> RDS
    ME --> RDS
    AU --> REDIS
    BI --> REDIS
    ME --> REDIS
    ID --> MSK
    AU --> MSK
    BI --> MSK
    WA --> MSK
    ME --> MSK
    ME -->|"presigned PUT, task role"| S3
    ME --> NAT --> SMTP

    SM -.->|"ECS secrets"| App
    ECR -.->|image pull| App
    GHA -->|"OIDC, no stored keys"| OIDC
    GHA -->|"push images, force new deployment"| ECR
```
