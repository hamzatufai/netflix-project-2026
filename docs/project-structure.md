# ============================================================
# Project Structure — Netflix Data Pipeline
# ============================================================
# Purpose: Detailed breakdown of every folder and file
# Teaching Note: Understanding the project structure is like
#   knowing the layout of a kitchen before cooking. Each folder
#   has a specific purpose, and files follow naming conventions
#   so you always know where to find things.
# ============================================================


## Project Root

```
netflix-pipeline/
│
├── README.md
│   Purpose: Project overview, quick start guide, all bash commands
│   When to read: First thing when joining the project
│
├── .gitignore
│   Purpose: Prevents sensitive files from being committed to Git
│   Protects: credentials, terraform state, data files, editor configs
│
└── (folders listed below)
```


## Folder: terraform/

```
terraform/
│
├── providers.tf
│   ├── Purpose: Declares which cloud providers Terraform will manage
│   ├── Contains: AWS provider configuration, Terraform version constraints
│   ├── Run: terraform init (downloads provider plugins)
│   └── Teaching: This is always the first file Terraform reads
│
├── variables.tf
│   ├── Purpose: Defines all configurable inputs (like function parameters)
│   ├── Contains: AWS region, bucket name, Snowflake settings, validation rules
│   ├── Run: Never directly — loaded automatically by Terraform
│   └── Teaching: Variables make code reusable. Same code, different environments.
│
├── main.tf
│   ├── Purpose: Core infrastructure resources (what Terraform creates)
│   ├── Contains: S3 bucket, IAM role, policies, encryption, lifecycle rules
│   ├── Run: terraform plan (preview) → terraform apply (create)
│   └── Teaching: This is the "recipe" — variables.tf has ingredients, main.tf has instructions
│
├── outputs.tf
│   ├── Purpose: Values Terraform prints after apply (like a receipt)
│   ├── Contains: bucket name, IAM role ARN, stage URL, helpful commands
│   ├── Run: terraform output (view values)
│   └── Teaching: Outputs give you values needed for Snowflake SQL scripts
│
└── terraform.tfvars.example
    ├── Purpose: Template for actual variable values (copy to terraform.tfvars)
    ├── Contains: Example values with comments
    ├── Run: cp terraform.tfvars.example terraform.tfvars → then edit
    └── Teaching: Never commit terraform.tfvars — it has your AWS keys!
```


## Folder: sql/

```
sql/
│
├── 01_create_database_and_schema.sql
│   ├── Purpose: Create the Snowflake database and schema (containers)
│   ├── Run: First SQL script to run
│   ├── Creates: ANALYTICS_DB, NETFLIX_SCHEMA, ANALYTICS_WH
│   └── Teaching: Run order matters! Numbers prefix tells you the sequence.
│
├── 02_create_tables.sql
│   ├── Purpose: Create all tables that store Netflix data
│   ├── Run: After 01 (needs database and schema to exist first)
│   ├── Creates: RAW_WEEKLY_VIEWS, NETFLIX_WEEKLY_VIEWS, DATA_LOAD_LOG, CATEGORY_DIMENSION
│   └── Teaching: Raw tables are "landing zones" — clean tables are for analysis
│
├── 03_create_storage_integration_and_stage.sql
│   ├── Purpose: Connect Snowflake to your S3 bucket
│   ├── Run: After 02 (needs tables to exist for data loading)
│   ├── Creates: netflix_s3_integration, netflix_s3_stage
│   └── Teaching: The integration is the "handshake" between Snowflake and AWS
│
├── 04_load_data.sql
│   ├── Purpose: Load CSV data from S3 into Snowflake tables
│   ├── Run: After 03 (needs integration and stage to exist)
│   ├── Does: COPY INTO raw → INSERT INTO clean → Log the load
│   └── Teaching: Always load raw first, then transform to clean
│
└── 05_analysis_queries.sql
    ├── Purpose: Ready-to-use analytics queries
    ├── Run: After 04 (needs data to be loaded)
    ├── Contains: 7 analysis queries with detailed comments
    └── Teaching: Each query demonstrates a different SQL technique
```


## Folder: scripts/

```
scripts/
│
└── upload_to_s3.sh
    ├── Purpose: Upload CSV files from local machine to S3
    ├── Run: chmod +x scripts/upload_to_s3.sh && ./scripts/upload_to_s3.sh
    ├── Does: Validates CSV format → Uploads to S3 → Verifies upload
    └── Teaching: Always validate data before uploading. Errors caught early save debugging time.
```


## Folder: data/

```
data/
│
└── (CSV files go here)
    ├── Purpose: Local storage for Netflix weekly CSV files
    ├── Contains: 2026-05-25_global_weekly.csv and similar files
    ├── Note: This folder is in .gitignore — files are NOT committed to Git
    └── Teaching: Data files are often large and contain business data. Keep them out of version control.
```


## Folder: docs/

```
docs/
│
├── architecture.md
│   ├── Purpose: Visual diagrams showing data flow through the system
│   ├── Contains: ASCII art architecture diagrams, security model, component flow
│   ├── When to read: When you need to understand how the system connects
│   └── Teaching: Architecture diagrams are the "map" of your data pipeline
│
└── project-structure.md
    ├── Purpose: This file — detailed explanation of every folder and file
    ├── Contains: Descriptions, run order, teaching notes for each component
    ├── When to read: When you're unsure what a file does or where to find things
    └── Teaching: Good documentation saves hours of reading code to understand structure
```


## Execution Order (How to Run Everything)

```
STEP    COMMAND                              WHAT IT DOES
─────   ──────────────────────────────────   ──────────────────────────────────────
  1     cd terraform/                        Navigate to terraform folder
  2     cp terraform.tfvars.example          Create your variable values file
          terraform.tfvars
  3     nano terraform.tfvars                Edit with your AWS/Snowflake values
  4     terraform init                       Download AWS provider plugin
  5     terraform plan                       Preview what will be created
  6     terraform apply                      Create S3 bucket + IAM role
  7     cd ..                                Go back to project root
  8     mkdir -p data                        Create data folder
  9     cp /path/to/csv data/               Copy CSV files locally
  10    chmod +x scripts/upload_to_s3.sh    Make script executable
  11    ./scripts/upload_to_s3.sh           Upload CSV files to S3
  12    Open Snowflake console              Go to your Snowflake web interface
  13    Run sql/01_create_database...sql    Create database and schema
  14    Run sql/02_create_tables.sql        Create all tables
  15    Edit sql/03 (replace IAM ARN)       Add your Terraform IAM role ARN
  16    Run sql/03_create_storage...sql     Connect Snowflake to S3
  17    Run sql/04_load_data.sql            Load CSV data into tables
  18    Run sql/05_analysis_queries.sql     Start analyzing your data!
```


## Key Naming Conventions

```
Convention               Example                    Why
─────────────────────    ──────────────────────     ──────────────────────────────────
Numbered SQL files       01_create_database.sql     Shows execution order at a glance
UPPER_CASE tables        RAW_WEEKLY_VIEWS           Snowflake convention for table names
snake_case variables     bucket_name                Terraform convention for variables
PREFIXnames for roles    snowflake-s3-reader        Shows purpose of the resource
.md for docs             architecture.md            Standard for markdown documentation
.sh for scripts          upload_to_s3.sh            Standard for bash scripts
```
