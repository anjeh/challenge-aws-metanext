# TAL Craftsmen — AWS CloudCraft Challenge (Terraform v1)

**Scope:** Deploy the *primary* architecture only in `eu-west-3` across two AZs. **Cross-region DR is documentation only in v1**, per the challenge's one-region restriction. No DR-region resources or DR testing are part of this repository.

## Architecture

```text
                         Internet
                            |
                Public ALB (HTTP :80)
                 /                    \
          public subnet A       public subnet B
                 |                    |
          ECS Fargate A          ECS Fargate B       <- private app subnets
                 \                   /
                  Regional NAT Gateway              <- outbound egress in both AZs
                           |
             Private PostgreSQL RDS Multi-AZ
                  (isolated DB subnets)
```

More precisely, the ALB routes to ECS targets in both private app subnets; ECS uses the regional NAT for egress to ECR, CloudWatch and APIs. The NAT is not on the ALB-to-ECS or ECS-to-RDS path. RDS primary and standby are in separate AZs, with no public endpoint.

## Included

- VPC + Internet Gateway; two AZs; **2 public, 2 private application, 2 isolated database subnets**
- **Regional public NAT Gateway** with automatic AZ affinity; one Terraform resource but **costs per active AZ** (not one zonal gateway price)
- Internet-facing ALB, private ECS Fargate with 2 tasks and CPU target-tracking scaling up to 4 tasks
- ECS deployment circuit breaker + rollback; ALB health checks
- Private, encrypted PostgreSQL RDS with Multi-AZ enabled by default and 7-day automated backups
- RDS admin password managed by RDS/Secrets Manager; **never injected into ECS**
- Optional application-specific Secrets Manager secret ARN for DB_USER/DB_PASSWORD (secret must already exist with JSON keys `username`, `password`; team creates and populates it out-of-band)
- ECR repository with image scanning, immutable tags, 10-image retention
- CloudWatch log group (7-day retention), unhealthy-target alarm, optional monthly AWS Budget email warning
- Common tags on managed resources

### Deliberately excluded

EFS, CloudFront, EKS, VPC endpoints, WAF, cross-region resources, DR automation, DNS automation, application-specific schema/migration, HTTPS/ACM (see security caveat), and running standby in another AWS region.

## Requirements

- AWS account with permissions for VPC, NAT, ALB, ECS, RDS, ECR, IAM, CloudWatch and optionally Budgets
- Terraform >= 1.5 and AWS provider >= 6.24, < 7 (regional NAT support)
- AWS CLI authenticated (profile or role)
- **Reachable, secure Terraform state storage**; by team assumption state is maintained in the datacenter. For local prototype runs the state is local until your team configures a suitable remote backend; DO NOT commit the state.

## Deployment: two deliberate stages (one state)

Terraform infers most creation order from references, but **it cannot ensure an image exists in ECR, a secret has a populated value, or an application DB user/schema has been prepared**. The `enable_app` switch (default `false`) prevents registering the ECS task and starting the ECS service before those prerequisites exist. ECS autoscaling and the unhealthy-target alarm are also disabled until the service is enabled. The ECS cluster, load balancer, target group, and other infrastructure can be created during foundation apply.

**Stage 1 — infrastructure only:**

```bash
cp terraform.tfvars.example terraform.tfvars
# Keep enable_app = false initially
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=foundation.tfplan
terraform apply foundation.tfplan
terraform output ecr_repository_url
```

This creates VPC, subnets, NAT, ALB (no registered targets), IAM, ECR, RDS, ECS cluster, logs and optional budget. **The website URL is deliberately null** until an application has been enabled. A browser request to the empty ALB will not serve your site.

**Stage 2 — prepare the application manually:**

1. Build and push a versioned Docker image using the optional GitHub ECR workflow or your own pipeline, and record the full ECR image URI (prefer immutable digest/tag).
2. If the app uses PostgreSQL: create its least-privileged database user, grant access, apply schema migrations exactly once, and create/populate an app-specific Secrets Manager JSON secret with `username` and `password`. The Terraform state must not hold passwords. Record that secret's ARN as `app_db_secret_arn`.
3. Confirm Dockerfile, port, health-check path, network/database access, and security group permissions. For a static Nginx demo, database setup is unnecessary, but an unused RDS still incurs costs.

**Stage 3 — enable ECS only after readiness checks:**

Edit `terraform.tfvars` and set `enable_app = true`, `container_image = "ACCOUNT.dkr.ecr.eu-west-3.amazonaws.com/REPO:TAG"`, and the secret ARN if required, then:

```bash
terraform plan -out=app.tfplan
terraform apply app.tfplan
terraform output website_url
```

A new image tag is deployed by updating `container_image` and applying again. **Do not use `terraform -target` for staging.** Avoid repeatedly switching `enable_app` back to false: that is a request to destroy the application service (not the database). No separate Terraform state is needed for the two stages.

**Readiness vs dependencies:** Terraform waits for resource provisioning, not for application-specific SQL readiness. Before setting `enable_app=true`, confirm the image, secrets and DB schema; after applying, test ALB health, logs and real application queries. `depends_on` is used only for IAM/listener ordering not expressed through direct references.

## Application credentials (optional)

- RDS manages an admin secret automatically. Never put its password into Terraform variables or inject it into ECS.
- For an app that needs DB access, a DBA must create a limited-privilege Postgres account and an AWS Secrets Manager JSON secret: `{"username":"appuser","password":"..."}`. Create/populate the value manually and securely, **not in Terraform**. Specify its ARN in `app_db_secret_arn`.
- This Terraform does **not** create the application login in PostgreSQL; it must be provisioned separately. If using a customer-managed KMS key for the secret, grant the ECS execution role `kms:Decrypt` on that key as appropriate.
- DB host/name/port are passed as ordinary environment variables; only username/password use ECS secret injection.
- Never commit `terraform.tfvars`, credentials, Terraform state, `.env`, or images containing secrets.

## GitHub repository setup

1. Create a new GitHub repository and commit these files (do **not** commit local state or `.tfvars`).
2. `.github/workflows/terraform-check.yml` runs `fmt`, `init -backend=false` and `validate` on PRs and pushes. **It does not deploy**.
3. `.github/workflows/ecr-build.yml` is optional/manual. Add your application `Dockerfile`, define GitHub Actions variable `AWS_GITHUB_ECR_ROLE_ARN` with an OIDC-assumable role ARN and `ECR_REPOSITORY` with the ECR repository name, and grant that role least-privilege ECR push permissions. Then manually run the workflow with an immutable tag.
4. Terraform application is deliberately manual from a trusted machine with datacenter-state connectivity. Do not use GitHub Actions to `apply` unless that backend and least-privilege authentication are formally configured.
5. OIDC role trust must be restricted to this repository and its intended branch/environment; **do not store long-lived AWS keys as GitHub secrets**.

## Resilience, safety and costs

- NAT egress uses **regional NAT** and scales its zonal capacity with participating AZs; hourly fees are based on active AZs plus data processing. This is not necessarily cheaper than two zonal NAT gateways. For a cheaper non-HA demo, a single zonal NAT would be possible but is **not used here**.
- Two ECS tasks, ALB subnets in both AZs and Multi-AZ RDS demonstrate an AZ-failure design. Actual failover has not been tested and cannot be claimed as demonstrated.
- Multi-AZ RDS, regional NAT, ALB and ECS are recurring cost drivers. Budget notifications **do not stop spending**. Budget thresholds are in USD, not EUR.
- This is an **HTTP-only demo**. For sensitive or public production traffic, add ACM+HTTPS (and redirect HTTP), tighter SG egress and least-privilege app database permissions.
- RDS `skip_final_snapshot=true` and `deletion_protection=false` simplify challenge teardown but can permanently delete database state. Update for real workloads.
- **Known trade-off:** enabling app secret injection pulls its contents at task start; rotating credentials requires a new ECS deployment, and IAM/KMS permissions must be checked.

## Teardown

```bash
terraform destroy
```

Destroy RDS only after an explicit data-retention decision. Clean up final snapshots/images separately if required to avoid continued charges.

## Documentation

- [`docs/architecture-and-scoring.md`](docs/architecture-and-scoring.md) — architectural choices and jury scoring
- [`docs/disaster-recovery.md`](docs/disaster-recovery.md) — **proposal only**, no DR implementation/deployment
- [`docs/manual-checklist.md`](docs/manual-checklist.md) — manual deployment and review checklist

## Sources

- Official CloudCraft presentation supplied by organizers (scope: one region `eu-west-3`, two AZs, ECS 256 CPU/512 MiB, evaluation rubric and deadline).
- AWS Provider NAT gateway docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway
- AWS RDS secret management: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html
