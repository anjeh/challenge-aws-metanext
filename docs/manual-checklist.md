# Primary deployment checklist

- [ ] Confirm AWS credentials/account, `eu-west-3` and authorized 2 AZs.
- [ ] Confirm cost approval: regional NAT by active AZ, Multi-AZ RDS, ALB and Fargate tasks.
- [ ] Configure a secure datacenter-backed Terraform remote state; enable encryption, state locking, backup and ACLs; **do not commit state**.
- [ ] Run `terraform fmt -check -recursive`, `terraform init`, `terraform validate`, and review `terraform plan`.
- [ ] Apply and confirm the public ALB URL returns the demo page.
- [ ] Confirm ECS has 2 running tasks placed in distinct AZs and no public IPs.
- [ ] Confirm RDS is private and Multi-AZ; SG rules block public access.
- [ ] Verify CloudWatch logs, unhealthy target alarm and optional AWS Budget.
- [ ] Build app Docker image; push an immutable tag to ECR and set `container_image`.
- [ ] If app needs PostgreSQL, manually provision a limited-privilege DB user and app Secrets Manager secret; set `app_db_secret_arn`. Never use the master password for ECS.
- [ ] Test simple ECS deploy/rollback (and document results); verify health check path.
- [ ] Add HTTPS/ACM + 80->443 redirect before exposing real user data.
- [ ] Document NAT/RDS recurring cost and actual AWS Cost Explorer figures.
- [ ] Produce draw.io schematic using official AWS icons and a short jury justification.
- [ ] Keep DR as **documentation only**, with zero other-region deployments or tests.

## Two-stage deployment gate

- [ ] First apply with `enable_app=false`: no ECS application tasks/service, scaling or unhealthy-target alarm should be present.
- [ ] ECR image exists in eu-west-3, and `container_image` points to the intended immutable tag/digest.
- [ ] If database is used, SQL app user/schema/migration has been prepared and the JSON app secret has a value; secret ARN is set.
- [ ] Set `enable_app=true` and apply. Confirm at least two healthy targets, website behavior and application-to-database connectivity.
- [ ] On subsequent releases, change the image tag; don't disable `enable_app` to redeploy.
