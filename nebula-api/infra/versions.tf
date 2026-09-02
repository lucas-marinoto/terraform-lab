terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Application = var.application_name
      Environment = var.environment
    }
  }
}
