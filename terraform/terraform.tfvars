# ============================================================
# terraform.tfvars.example — Example Variable Values
# Purpose: Copy this file to `terraform.tfvars` and fill in your values
# Teaching Note: NEVER commit terraform.tfvars to Git — it contains secrets!
#
#   How to use:
#     1. Copy this file:  cp terraform.tfvars.example terraform.tfvars
#     2. Edit terraform.tfvars with your actual values
#     3. Run:  terraform plan   (to preview changes)
#     4. Run:  terraform apply  (to create resources)
# ============================================================

# ---- AWS Settings ----
aws_region   = "us-east-1"          # Which AWS region to use
environment  = "dev"                 # dev, staging, or production
bucket_name  = "netflix_2026"        # S3 bucket name for Netflix data

# ---- Snowflake Settings ----
# WARNING: Get these from your Snowflake console or IT team
snowflake_account_url   = "https://your-account.us-east-1.snowflakecomputing.com"
snowflake_iam_role_arn  = "arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_ROLE"
snowflake_database      = "ANALYTICS_DB"
snowflake_schema        = "NETFLIX_SCHEMA"

# ---- S3 Data Settings ----
data_prefix = "weekly-data/"        # Folder inside S3 bucket for CSV files
