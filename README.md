# ============================================================
# Netflix Data Pipeline — README.md
# ============================================================
# Purpose: Main entry point for the project. Everything you need
#   to set up, run, and use this pipeline is here.
# Teaching Note: A good README answers 3 questions in 30 seconds:
#   1. What is this? (Overview)
#   2. How do I set it up? (Prerequisites + Setup)
#   3. How do I run it? (Quick Start)
# ============================================================


## 📋 Overview

This project is a **complete data pipeline** that loads Netflix weekly viewership data from CSV files into Snowflake for analysis.

**What it does:**
1. Creates an S3 bucket using Terraform (Infrastructure as Code)
2. Creates an IAM role so Snowflake can read from S3
3. Uploads Netflix CSV data to S3
4. Loads the data into Snowflake tables
5. Provides analysis queries to explore the data

**Data Source:** Netflix Global Weekly Top 10 (CSV format)
**Data Target:** Snowflake Analytics Database


## 🏗️ Architecture

```
CSV File ──▶ S3 Bucket ──▶ Snowflake RAW Table ──▶ Snowflake CLEAN Table ──▶ Analysis
             (Terraform)     (COPY INTO)           (INSERT + Transform)     (Queries)
```

See `docs/architecture.md` for detailed diagrams.


## 📁 Project Structure

```
netflix-pipeline/
├── README.md                          # You are here
├── .gitignore                         # Protects secrets from Git
│
├── terraform/                         # AWS Infrastructure (S3 + IAM)
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
│
├── sql/                               # Snowflake Scripts (run in order)
│   ├── 01_create_database_and_schema.sql
│   ├── 02_create_tables.sql
│   ├── 03_create_storage_integration_and_stage.sql
│   ├── 04_load_data.sql
│   └── 05_analysis_queries.sql
│
├── scripts/
│   └── upload_to_s3.sh               # Upload CSV files to S3
│
├── data/                              # Local CSV files (not in Git)
│
└── docs/
    ├── architecture.md
    └── project-structure.md
```


## ✅ Prerequisites

Before starting, install these tools:

### 1. AWS CLI (Command Line Interface)
```bash
# Check if installed
aws --version

# If not installed, download from:
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

# Configure with your AWS credentials
aws configure
# Enter: AWS Access Key ID
# Enter: AWS Secret Access Key
# Enter: Default region (us-east-1)
# Enter: Default output format (json)
```

### 2. Terraform (Infrastructure as Code)
```bash
# Check if installed
terraform --version

# If not installed, download from:
# https://developer.hashicorp.com/terraform/downloads

# Verify installation
terraform version
```

### 3. Snowflake Account
```bash
# You need a Snowflake account with:
# - SYSADMIN role (to create databases/tables)
# - SECURITYADMIN role (to create integrations)
# - Access to Snowflake web console
```

### 4. CSV Data File
```bash
# Place your Netflix CSV file in the data/ folder
# Example: data/2026-05-25_global_weekly.csv
```


## 🚀 Quick Start (5 Steps)

### Step 1: Set Up Infrastructure (Terraform)

```bash
# Navigate to terraform folder
cd terraform

# Create your variables file (copy the template)
cp terraform.tfvars.example terraform.tfvars

# Edit the variables file with your values
# Use any text editor (nano, vim, VS Code, etc.)
nano terraform.tfvars
```

**Edit these values in terraform.tfvars:**
```bash
aws_region             = "us-east-1"
environment            = "dev"
bucket_name            = "netflix_2026"
snowflake_account_url  = "https://YOUR-ACCOUNT.us-east-1.snowflakecomputing.com"
snowflake_iam_role_arn = "arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_ROLE"
```

```bash
# Initialize Terraform (downloads AWS provider)
terraform init

# Preview what will be created
terraform plan

# Create the resources
terraform apply
# Type 'yes' when prompted
```

**Save these outputs from the apply:**
```
bucket_name      = "netflix_2026"
snowflake_role_arn = "arn:aws:iam::123456789012:role/snowflake-s3-reader-dev"
```

### Step 2: Upload Data to S3

```bash
# Go back to project root
cd ..

# Create data folder (if not exists)
mkdir -p data

# Copy your CSV file to data/ folder
cp /path/to/your/2026-05-25_global_weekly.csv data/

# Make upload script executable
chmod +x scripts/upload_to_s3.sh

# Run the upload
./scripts/upload_to_s3.sh
```

**Expected output:**
```
✓ AWS CLI is installed
✓ AWS credentials are configured
✓ S3 bucket 'netflix_2026' exists
✓ Found 1 CSV file(s) to upload
upload: data/2026-05-25_global_weekly.csv to s3://netflix_2026/weekly-data/...
✓ All files uploaded successfully!
```

### Step 3: Create Snowflake Database and Tables

Open the **Snowflake web console** and run these SQL scripts **in order**:

```sql
-- Script 01: Create database and schema
-- Copy and paste this into Snowflake worksheet, then run it
USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS ANALYTICS_DB;
CREATE SCHEMA IF NOT EXISTS NETFLIX_SCHEMA;
CREATE WAREHOUSE IF NOT EXISTS ANALYTICS_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;
```

```sql
-- Script 02: Create tables
-- Run the full 02_create_tables.sql file
USE DATABASE ANALYTICS_DB;
USE SCHEMA NETFLIX_SCHEMA;
-- (Paste the rest of the file)
```

### Step 4: Connect Snowflake to S3

```sql
-- Script 03: Create storage integration
-- IMPORTANT: Replace YOUR_IAM_ROLE_ARN with the terraform output value

USE ROLE SECURITYADMIN;

CREATE OR REPLACE STORAGE INTEGRATION netflix_s3_integration
    TYPE = EXTERNAL_STAGE
    ENABLED = TRUE
    STORAGE_PROVIDER = S3
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789012:role/snowflake-s3-reader-dev'
    -- ^^^ REPLACE THIS WITH YOUR ACTUAL IAM ROLE ARN ^^^
    STORAGE_AWS_EXTERNAL_ID = 'NETFLIX_PIPELINE_dev';

GRANT USAGE ON INTEGRATION netflix_s3_integration TO ROLE SYSADMIN;

-- Create the stage
USE ROLE SYSADMIN;

CREATE OR REPLACE STAGE netflix_s3_stage
    URL = 's3://netflix_2026/weekly-data/'
    STORAGE_INTEGRATION = netflix_s3_integration
    FILE_FORMAT = (
        TYPE = 'CSV'
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        SKIP_HEADER = 1
        NULL_IF = ('', 'N/A', 'null', 'NULL')
        TRIM_SPACE = TRUE
        EMPTY_FIELD_AS_NULL = TRUE
    );

-- Verify connection
LIST @netflix_s3_stage;
```

### Step 5: Load Data and Analyze

```sql
-- Script 04: Load data
-- Run the full 04_load_data.sql file

USE DATABASE ANALYTICS_DB;
USE SCHEMA NETFLIX_SCHEMA;
USE WAREHOUSE ANALYTICS_WH;

-- Copy into raw table
COPY INTO RAW_WEEKLY_VIEWS
FROM @netflix_s3_stage
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"' NULL_IF = ('N/A'));
```

```sql
-- Script 05: Start analyzing!
-- Run any query from 05_analysis_queries.sql

-- Example: Top 10 most viewed shows
SELECT
    show_title,
    SUM(weekly_hours_viewed) AS total_hours_viewed
FROM NETFLIX_WEEKLY_VIEWS
GROUP BY show_title
ORDER BY total_hours_viewed DESC
LIMIT 10;
```


## 📊 Quick Analysis Queries

Once data is loaded, try these in Snowflake:

```sql
-- How many rows loaded?
SELECT COUNT(*) FROM NETFLIX_WEEKLY_VIEWS;

-- What categories exist?
SELECT DISTINCT category FROM NETFLIX_WEEKLY_VIEWS;

-- Top show this week
SELECT show_title, weekly_hours_viewed
FROM NETFLIX_WEEKLY_VIEWS
WHERE week = '2026-05-17'
ORDER BY weekly_hours_viewed DESC
LIMIT 5;

-- All time most watched
SELECT
    show_title,
    SUM(weekly_hours_viewed) AS total_hours
FROM NETFLIX_WEEKLY_VIEWS
GROUP BY show_title
ORDER BY total_hours DESC
LIMIT 10;
```


## 🛠️ All Bash Commands (Copy-Paste Reference)

```bash
# ============================================
# SETUP COMMANDS (Run once)
# ============================================

# Check tools are installed
aws --version
terraform --version

# Configure AWS credentials
aws configure

# Navigate to project
cd netflix-pipeline

# Set up Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
cd ..

# Create data folder and add CSV files
mkdir -p data
cp /path/to/your/*.csv data/

# Upload to S3
chmod +x scripts/upload_to_s3.sh
./scripts/upload_to_s3.sh


# ============================================
# TERRAFORM COMMANDS
# ============================================

# Initialize (download providers)
terraform init

# Preview changes
terraform plan

# Apply changes (create resources)
terraform apply

# View outputs (bucket name, IAM role ARN)
terraform output

# Destroy all resources (careful!)
terraform destroy


# ============================================
# AWS S3 COMMANDS
# ============================================

# List files in bucket
aws s3 ls s3://netflix_2026/weekly-data/

# Download a file from S3
aws s3 cp s3://netflix_2026/weekly-data/file.csv ./downloaded.csv

# Check bucket exists
aws s3api head-bucket --bucket netflix_2026

# Get bucket region
aws s3api get-bucket-location --bucket netflix_2026


# ============================================
# SNOWFLAKE COMMANDS (Run in Snowflake Console)
# ============================================

# List databases
SHOW DATABASES;

# List tables in schema
SHOW TABLES IN SCHEMA ANALYTICS_DB.NETFLIX_SCHEMA;

# List files in stage
LIST @netflix_s3_stage;

# Check table row counts
SELECT COUNT(*) FROM RAW_WEEKLY_VIEWS;
SELECT COUNT(*) FROM NETFLIX_WEEKLY_VIEWS;

# Check load history
SELECT * FROM DATA_LOAD_LOG;
```


## 🔧 Troubleshooting

| Problem | Solution |
|---------|----------|
| `terraform init` fails | Check internet connection, try `terraform init -upgrade` |
| `terraform apply` fails with permissions | Check your AWS credentials: `aws sts get-caller-identity` |
| S3 upload fails | Run `aws configure` and verify your access key |
| Snowflake can't see S3 files | Verify IAM role ARN in storage integration matches terraform output |
| COPY INTO returns 0 rows | Check stage URL, file format, and CSV header |
| CSV format error | Ensure CSV has header row and uses commas as delimiters |


## 📚 Additional Resources

- **Architecture Diagram:** `docs/architecture.md`
- **Project Structure:** `docs/project-structure.md`
- **Terraform Docs:** https://developer.hashicorp.com/terraform/docs
- **Snowflake Docs:** https://docs.snowflake.com/
- **AWS S3 Docs:** https://docs.aws.amazon.com/s3/


## 📝 Notes

- **Never commit** `terraform.tfvars` to Git (it contains your AWS keys)
- **Always run SQL scripts in order** (01 → 02 → 03 → 04 → 05)
- **Keep the data/ folder** with your CSV files — it's not in Git
- **Run `terraform destroy`** to clean up resources when done
