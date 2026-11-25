terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.24.0, < 7.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project_name
      Team        = "TAL-Craftsmen"
      Environment = "challenge"
      ManagedBy   = "Terraform"
      CostCenter  = "CloudCraft"
    }
  }
}
