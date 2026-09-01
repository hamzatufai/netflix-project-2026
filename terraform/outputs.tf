# ============================================================
# outputs.tf — Output Values
# Purpose: Print important values after `terraform apply` so you
#          can use them in Snowflake SQL scripts
# Teaching Note: Outputs are like a receipt — they show you what
#   Terraform created and give you values you need for next steps.
#
#   Example: After running `terraform apply`, you'll see:
#     bucket_name = "netflix_2026"
#     iam_role_arn = "arn:aws:iam::123456789:role/snowflake-s3-reader-dev"
#   Copy these into your Snowflake SQL scripts.
# ============================================================

# ---- S3 Bucket Name ----
# WHY: You need this for the Snowflake STAGE definition
#      It tells Snowflake WHERE to find the CSV files
output "bucket_name" {
  description = "Name of the S3 bucket created for Netflix data"
  value       = aws_s3_bucket.netflix_data.id

  # Teaching: This prints after apply so you can copy it to SQL
  # Example output: bucket_name = "netflix_2026"
}

# ---- S3 Bucket ARN (Amazon Resource Name) ----
# WHY: The ARN is a unique identifier for the bucket across all of AWS
#      Sometimes needed for cross-account policies or CloudWatch
output "bucket_arn" {
  description = "ARN of the S3 bucket (unique AWS identifier)"
  value       = aws_s3_bucket.netflix_data.arn

  # Example output: bucket_arn = "arn:aws:s3:::netflix_2026"
}

# ---- S3 Bucket Region ----
# WHY: Tells you which region the bucket is in (needed for Snowflake stage URL)
output "bucket_region" {
  description = "AWS region where the S3 bucket is located"
  value       = aws_s3_bucket.netflix_data.region

  # Example output: bucket_region = "us-east-1"
}

# ---- IAM Role ARN for Snowflake ----
# WHY: CRITICAL — This is what you paste into Snowflake when creating
#      an external stage. Snowflake uses this ARN to assume the role
#      and access your S3 bucket.
output "snowflake_role_arn" {
  description = "ARN of the IAM role Snowflake should assume to read from S3"
  value       = aws_iam_role.snowflake_s3_reader.arn
  sensitive   = false   # ARN is not secret, it's just an identifier

  # Example output: snowflake_role_arn = "arn:aws:iam::123456789012:role/snowflake-s3-reader-dev"
  #
  # USE THIS IN SQL:
  #   CREATE STORAGE INTEGRATION netflix_s3_integration
  #     STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789012:role/snowflake-s3-reader-dev'
}

# ---- Data Upload Instructions ----
# WHY: Reminds you how to upload files after Terraform creates the bucket
output "upload_command" {
  description = "AWS CLI command to upload CSV data to the bucket"
  value       = "aws s3 cp data/ s3://${aws_s3_bucket.netflix_data.id}/weekly-data/ --recursive"

  # Teaching: This is a convenience output — copy-paste this command to upload data
}

# ---- Snowflake Stage URL Template ----
# WHY: Provides the S3 URL format needed for Snowflake external stages
output "snowflake_stage_url" {
  description = "S3 URL format for Snowflake external stage definition"
  value       = "s3://${aws_s3_bucket.netflix_data.id}/weekly-data/"

  # USE THIS IN SQL:
  #   CREATE STAGE netflix_s3_stage
  #     URL = 's3://netflix_2026/weekly-data/'
}
