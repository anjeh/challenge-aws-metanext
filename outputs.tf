output "website_url" {
  value       = var.enable_app ? "http://${aws_lb.main.dns_name}" : null
  description = "Open this URL after ECS targets become healthy"
}
output "db_endpoint_private" {
  value       = aws_db_instance.main.endpoint
  description = "Private RDS endpoint; not reachable from the public internet"
}
output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}
output "nat_gateway_id" {
  value = aws_nat_gateway.main.id
}
output "rds_multi_az_enabled" {
  value = aws_db_instance.main.multi_az
}

output "ecs_service_name" {
  value = var.enable_app ? aws_ecs_service.app[0].name : null
}

output "rds_master_secret_arn" {
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
  description = "Managed master secret ARN for administrators only, NOT the application"
}

output "application_enabled" {
  value       = var.enable_app
  description = "False until the application image, configuration and optional secrets are ready"
}
output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "Created during foundation stage; does not serve an application until enable_app=true"
}
