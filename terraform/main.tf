# ============================================================
# main.tf — Core Infrastructure Resources
# Purpose: Create S3 bucket + IAM role so Snowflake can load CSV data
# Teaching Note: This file defines the actual cloud resources Terraform creates.
#   Think of it as the "recipe" — variables.tf has the ingredients,
#   and main.tf has the cooking instructions.
#
#   Data Flow: CSV file → S3 Bucket → (IAM Role) → Snowflake Table
# ============================================================

# ============================================================
# SECTION 1: S3 BUCKET — Where CSV files are stored
# ============================================================

# ---- S3 Bucket Resource ----
# WHY: This is the central storage location. Netflix weekly CSVs will
#      be uploaded here, then Snowflake reads them via an external stage.
resource "aws_s3_bucket" "netflix_data" {
  bucket = var.bucket_name   # Uses variable for flexibility

  # ---- Prevent Deletion Safety ----
  # WHY: In production, you don't want `terraform destroy` to accidentally
  #      delete a bucket full of historical data
  force_destroy = (var.environment == "dev")   # Only allow deletion in dev

  tags = {
    Name        = "Netflix Weekly Data Storage"
    Description = "Stores Netflix weekly viewership CSV files for Snowflake loading"
  }
}

# ---- Bucket Versioning ----
# WHY: Keeps previous versions of files if someone accidentally overwrites data
#      This is like Git history for your data files
resource "aws_s3_bucket_versioning" "netflix_data_versioning" {
  bucket = aws_s3_bucket.netflix_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ---- Bucket Server-Side Encryption ----
# WHY: Data at rest should always be encrypted. This is an AWS best practice
#      and often required for compliance (GDPR, SOC2, etc.)
resource "aws_s3_bucket_server_side_encryption_configuration" "netflix_data_encryption" {
  bucket = aws_s3_bucket.netflix_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"   # AWS-managed encryption (free)
    }
    bucket_key_enabled = true   # Reduces API costs
  }
}

# ---- Block Public Access ----
# WHY: Netflix viewership data should NEVER be publicly accessible.
#      This is a critical security control.
resource "aws_s3_bucket_public_access_block" "netflix_data_public_access" {
  bucket = aws_s3_bucket.netflix_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---- Lifecycle Rules (Cost Optimization) ----
# WHY: Old data versions cost money. Move them to cheaper storage tiers
#      or delete them after a set period.
resource "aws_s3_bucket_lifecycle_configuration" "netflix_data_lifecycle" {
  bucket = aws_s3_bucket.netflix_data.id

  rule {
    id     = "archive-old-data"
    status = "Enabled"

    # Move old versions to cheaper storage after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"   # Infrequent Access (~40% cheaper)
    }

    # Move to Glacier after 90 days (archival)
    transition {
      days          = 90
      storage_class = "GLACIER"   # Deep archive (~75% cheaper)
    }

    # Delete old versions after 365 days
    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}


# ============================================================
# SECTION 2: IAM ROLE — Grants Snowflake permission to read S3
# ============================================================

# ---- IAM Role for Snowflake ----
# WHY: Snowflake doesn't have direct access to your AWS account.
#      You create a "role" (like a user account for Snowflake) that
#      Snowflake assumes using STS (Security Token Service).
#      
#      This is the TRUST relationship — who is allowed to use this role?
resource "aws_iam_role" "snowflake_s3_reader" {
  name = "snowflake-s3-reader-${var.environment}"   # e.g., snowflake-s3-reader-dev

  # ---- Trust Policy ----
  # WHY: This JSON policy says "Only Snowflake's AWS account can assume this role"
  #      It's like giving a key to a specific person, not everyone
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.snowflake_iam_role_arn}:root"
        }
        Action    = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "NETFLIX_PIPELINE_${var.environment}"
          }
        }
      }
    ]
  })

  tags = {
    Purpose = "Allows Snowflake to read Netflix CSV data from S3"
  }
}

# ---- IAM Policy for S3 Read Access ----
# WHY: The role alone isn't enough. You need to specify EXACTLY what
#      the role can do. Here we say "read-only access to our specific bucket"
resource "aws_iam_role_policy" "snowflake_s3_read" {
  name = "snowflake-s3-read-${var.environment}"
  role = aws_iam_role.snowflake_s3_reader.id

  # ---- Permission Policy ----
  # WHY: Least privilege principle — only grant what's needed, nothing more
  #      This role can only READ (list + get), not WRITE or DELETE
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBucketList"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",        # Can see what files are in the bucket
          "s3:GetBucketLocation"  # Can check which region the bucket is in
        ]
        Resource = aws_s3_bucket.netflix_data.arn
      },
      {
        Sid    = "AllowObjectRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",              # Can download/read files
          "s3:GetObjectVersion"        # Can read specific file versions
        ]
        Resource = "${aws_s3_bucket.netflix_data.arn}/*"   # All objects in bucket
      }
    ]
  })
}


# ============================================================
# SECTION 3: OUTPUTS — Values to use after Terraform apply
# ============================================================

# NOTE: These are duplicated in outputs.tf for clarity.
#      In a real project, keep them in one place only.
