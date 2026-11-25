variable "aws_region" {
  description = "Challenge region"
  type        = string
  default     = "eu-west-3"
  validation {
    condition     = var.aws_region == "eu-west-3"
    error_message = "CloudCraft challenge deployments are limited to eu-west-3."
  }
}
variable "project_name" {
  description = "Prefix for AWS resource names"
  type        = string
  default     = "cloudcraft"
}
variable "container_image" {
  description = "Public image URI or an ECR image URI. Replace the default nginx demo with your application image."
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:stable-alpine"
}
variable "container_port" {
  description = "HTTP port exposed by the container"
  type        = number
  default     = 80
}
variable "db_name" {
  type    = string
  default = "appdb"
}
variable "db_username" {
  type    = string
  default = "appadmin"
}
variable "desired_count" {
  type    = number
  default = 2
}

variable "db_multi_az" {
  description = "Enable RDS standby in second AZ (higher cost, recommended for end-to-end AZ resilience)"
  type        = bool
  default     = true
}
variable "max_tasks" {
  description = "ECS autoscaling upper bound"
  type        = number
  default     = 4
}
variable "budget_email" {
  description = "Email to receive AWS budget warning. Empty string disables budget creation."
  type        = string
  default     = ""
}
variable "monthly_budget_usd" {
  description = "Monthly AWS cost budget threshold in USD"
  type        = number
  default     = 100
}

variable "app_db_secret_arn" {
  description = "Optional existing Secrets Manager secret ARN with JSON username/password for an app-specific RDS user. Empty disables ECS credential injection. Never use the RDS master account."
  type        = string
  default     = ""
}

variable "enable_app" {
  description = "Stage 1 (false): create AWS foundation without ECS tasks. Stage 2 (true): deploy app after image, DB schema/user, and optional secrets are ready."
  type        = bool
  default     = false
}
