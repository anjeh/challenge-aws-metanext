# Architecture decisions and scoring (jury note)

## Constraints
- Challenge deadline: **30 November 2026, 18:00**.
- Actual infrastructure only in **`eu-west-3`**, across two AZs.
- ECS task `cpu=256`, `memory=512` as mandated.
- Terraform is used for repeatability; no EFS (stateless container deployment).

## How we address the rubric

| Category | Weight | Implemented in primary Terraform | Limitations / next iteration |
| --- | ---: | --- | --- |
| Architecture and resilience | 30% | Segmented subnet tiers, ALB + 2 ECS tasks over two AZs, regional NAT, RDS Multi-AZ, scaling and health checks | AZ failover still requires a real test; max 4 tasks; capacity and recovery time not guaranteed |
| Security and data | 30% | SG traffic paths, isolated RDS, RDS encryption at rest, RDS-managed admin secret, optional app secret, IAM execution role | HTTP-only; CloudWatch/ECR use AWS managed encryption rather than dedicated CMKs, SG egress open for NAT; app least-privilege user is manual |
| Lifecycle and automation | 20% | ECR immutable images, 10-image retention, ECS deployment circuit breaker rollback, GitHub validation & manual ECR workflow | Actual frontend Docker build depends on project source; no automatic app rollout or proven rollback drill yet |
| Governance / FinOps | 10% | Default tags, CloudWatch log retention/alarm, optional AWS Budget | No full audit dashboard, Cost Explorer or CloudTrail setup in v1 |
| Communication / justification | 10% | README, explicit cost/security trade-offs, documented DR extension | draw.io architecture diagram must be created separately for final delivery |

## Key technical decisions
1. **Public ALB / private ECS / isolated RDS** keeps application compute and data off the public Internet. ALB -> ECS and ECS -> RDS are SG-restricted.
2. **Regional NAT instead of one zonal NAT** removes the explicit single-AZ NAT resource dependency. Billing follows per-active-AZ capacity; this is a resilience choice, not a claim of one-NAT pricing.
3. **Multi-AZ PostgreSQL** has a synchronous standby and automatic AZ failover, without turning PostgreSQL into a cross-region DR system.
4. **No EFS** because container file systems are treated as ephemeral; if the actual app needs durable uploads, store those explicitly in an appropriate durable service.
5. **Monitoring** includes an alarm, logs and autoscaling. The alarm is visible in CloudWatch but has no SNS notification until configured.
6. **Secrets**: master admin credentials are managed by RDS. The application uses a separately created secret and a minimum-privilege Postgres user if the frontend/backend actually accesses DB.

## Submission reminders
Required by organizers: a draw.io AWS-icon architecture diagram, a live site URL, and a short decision document. A successful DR drill is not claimed, because other-region deployments are prohibited by the challenge.
