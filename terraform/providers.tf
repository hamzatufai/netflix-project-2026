# ============================================================
# providers.tf — Provider Configuration
# Purpose: Define which cloud providers Terraform will manage
# Teaching Note: Always pin your provider versions for reproducibility
# ============================================================

# ---- Terraform Version Constraint ----
# WHY: Ensures everyone on the team uses the same Terraform version
terraform {
  required_version = ">= 1.5.0"

  # ---- Required Providers Block ----
  # WHY: Declares which providers this config needs and their versions
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"   # Pin to AWS provider 5.x for stability
    }
  }
}

# ---- AWS Provider Configuration ----
# WHY: Tells Terraform which AWS region and credentials to use
provider "aws" {
  region = var.aws_region   # Uses variable so region is configurable

  # ---- Default Tags ----
  # WHY: Automatically tags ALL resources created by this config
  #      This helps with cost tracking, resource identification
  default_tags {
    tags = {
      Project     = "Netflix-Pipeline"
      Environment = var.environment
      ManagedBy   = "Terraform"
      CreatedDate = "2026-05-25"
    }
  }
}
