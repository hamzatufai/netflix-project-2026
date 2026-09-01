

# ---- AWS Region ----
variable "aws_region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "us-east-1"   # Default to US East (cheapest, most services)
}

# ---- Environment ----
variable "environment" {
  description = "Deployment environment (dev, staging, production)"
  type        = string
  default     = "dev"

  # ---- Validation Rule ----
  # WHY: Prevents typos like "deve" or "prd" from creating resources
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production"
  }
}

# ---- S3 Bucket Name ----
variable "bucket_name" {
  description = "Name of the S3 bucket for Netflix CSV data storage"
  type        = string
  default     = "netflix_2026"

  # ---- Validation Rule ----
  # WHY: S3 bucket names have strict rules (lowercase, no underscores in some cases)
  #      This catches issues before Terraform tries to create the bucket
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters, lowercase alphanumeric with dots, hyphens, or underscores"
  }
}

# ---- Snowflake Account URL ----
variable "snowflake_account_url" {
  description = "Snowflake account URL (e.g., https://abc1234.snowflakecomputing.com)"
  type        = string
  sensitive   = true   # Hides value in terraform plan output
}

# ---- Snowflake Role for Data Loading ----
variable "snowflake_iam_role_arn" {
  description = "ARN of the IAM role that Snowflake assumes to read from S3"
  type        = string
  sensitive   = true
}

# ---- Snowflake Database Name ----
variable "snowflake_database" {
  description = "Target Snowflake database for Netflix data"
  type        = string
  default     = "ANALYTICS_DB"
}

# ---- Snowflake Schema Name ----
variable "snowflake_schema" {
  description = "Target Snowflake schema within the database"
  type        = string
  default     = "NETFLIX_SCHEMA"
}

# ---- Data Prefix (S3 Key) ----
variable "data_prefix" {
  description = "S3 key prefix (folder) where CSV files will be stored"
  type        = string
  default     = "weekly-data/"
}
