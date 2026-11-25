# Future cross-region disaster recovery — DESIGN ONLY (v1)

**No DR implementation, snapshots, AWS resources, scripts or tests are deployed to any other region in this version.** The challenge explicitly restricts deployments to `eu-west-3`.

## Intended v2: manually activated cold DR / backup and restore

- **Primary:** VPC, ALB, private ECS Fargate, Multi-AZ RDS PostgreSQL in Paris (`eu-west-3`).
- **Destination example:** Ireland (`eu-west-1`), subject to authorization outside this challenge.
- **Backups:** before any disaster, encrypted RDS snapshots must be copied to the DR region or automated cross-region backup replication must be configured. Merely exporting a snapshot to ordinary S3 is **not** a native RDS restorable snapshot. An outage can prevent any last-minute copy from a failed source region.
- **Application images:** dedicated ECR pipeline can target the DR region ahead of time. Images must be available independently of Paris.
- **Secrets:** Terraform can declare empty Secrets Manager resources in DR, followed by approved manual entry of application secret values. Avoid storing secret values in `.tfvars` or Terraform state; enforce a dependency so ECS is not started until secrets are ready.
- **KMS:** cross-region snapshot copy requires a usable destination-region KMS key established **before** the snapshot copy. Multi-Region KMS keys are unnecessary for this flow. Keys cannot be assumed to be transparently usable in another region.
- **Terraform state:** separate DR state kept on datacenter infrastructure, independently backed up and accessible during an AWS Paris outage.
- **Application config:** region-dependent, nonsensitive values (e.g. DB endpoint, app domain) supplied through Terraform/ECS environment variables; sensitive tokens in Secrets Manager. Audit callback URLs, CORS, uploaded files and external dependencies before DR.
- **Manual cutover:** operators validate database and app behavior and then change DNS to the DR ALB. No automatic failover is promised.

## Proposed manual recovery steps (not executable in v1)

1. Declare the incident and approve recovery.
2. Verify a **completed, restorable snapshot exists in DR** and document its timestamp, age and KMS grants.
3. Prepare destination-region KMS, IAM and private networking.
4. Terraform plan/apply the database and core infrastructure using **separate state** and the selected snapshot.
5. Provision/reconcile application DB users and populate destination Secrets Manager versions securely.
6. Ensure immutable app image is already in destination ECR; deploy ECS tasks via Terraform.
7. Check ALB healthy targets, API/database behavior, logs and security rules; switch DNS manually.
8. Monitor and define a later reverse-replication / failback plan.

## What this cannot guarantee

- **RPO:** equals the age of the latest *available DR-region* recoverable backup at time of incident, not the age of the latest snapshot in Paris.
- **RTO:** sum of operator approval, restore, image and secret readiness, ECS rollout, validation and DNS caching/propagation. Both are **unmeasured** without a DR drill.
- Cold DR without pre-positioned snapshots is only an infrastructure rebuild plan, **not** a reliable data recovery plan.
- Even after operationalizing, regional backups, image, secrets and state dependencies need monitoring; snapshots do not capture external files or uncommitted transactions.

## Cost posture

- **v1 (current):** $0 of DR-region resources and backup-copy spending; **no cross-region recoverability is asserted**.
- **v2 operational cold DR:** pay for encrypted backup storage/cross-region transfers, KMS key(s), optional ECR/secret storage; no always-on DR ALB/ECS/NAT/RDS until manual activation.
- This favors low ongoing cost over short RTO / RPO. Pricing varies with actual volume/region and should be assessed before authorization.
