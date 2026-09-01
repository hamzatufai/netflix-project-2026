# ============================================================
# Architecture Diagram — Netflix Data Pipeline
# ============================================================
# Purpose: Visual representation of how data flows through the system
# Teaching Note: An architecture diagram is the FIRST thing you should
#   look at when understanding a data pipeline. It answers:
#   - Where does data come from? (Source)
#   - Where does it go? (Destination)
#   - What happens in between? (Processing)
# ============================================================


## ASCII Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     NETFLIX DATA PIPELINE                              │
│                     Architecture Overview                               │
└─────────────────────────────────────────────────────────────────────────┘


  ┌──────────────┐        ┌──────────────┐        ┌──────────────────────┐
  │              │        │              │        │                      │
  │   CSV File   │───────▶│   AWS S3     │───────▶│     Snowflake        │
  │  (Source)    │        │   Bucket     │        │     (Warehouse)      │
  │              │        │              │        │                      │
  └──────────────┘        └──────────────┘        └──────────────────────┘
        │                       │                        │
        │                       │                        │
  ┌─────┴─────┐          ┌─────┴─────┐          ┌───────┴───────┐
  │           │          │           │          │               │
  │  Upload   │          │  Storage  │          │   Staging     │
  │  Script   │          │  Bucket   │          │   Table       │
  │  (Bash)   │          │  (S3)     │          │  (RAW)        │
  │           │          │           │          │               │
  └───────────┘          └───────────┘          └───────┬───────┘
                                                        │
                                                        │  Transform
                                                        │  (ELT)
                                                        │
                                                 ┌──────▼───────┐
                                                 │              │
                                                 │  Clean Table │
                                                 │  (PRODUCTION)│
                                                 │              │
                                                 └──────┬───────┘
                                                        │
                                              ┌─────────┴─────────┐
                                              │                   │
                                              │  Analysis Queries │
                                              │  (Reporting)      │
                                              │                   │
                                              └───────────────────┘
```


## Detailed Component Flow

```
┌────────────────────────────────────────────────────────────────────────────┐
│                           DETAILED DATA FLOW                              │
└────────────────────────────────────────────────────────────────────────────┘

PHASE 1: INFRASTRUCTURE SETUP (Terraform)
══════════════════════════════════════════

  Developer Machine                    AWS Cloud
  ─────────────────                    ─────────
  ┌──────────────┐                    ┌──────────────────┐
  │              │   terraform apply  │                  │
  │  terraform/  │──────────────────▶│  S3 Bucket       │
  │  (IaC)       │                    │  netflix_2026    │
  │              │                    │                  │
  └──────────────┘                    │  IAM Role        │
                                      │  snowflake-s3-   │
                                      │  reader-dev      │
                                      └──────────────────┘


PHASE 2: DATA UPLOAD (Bash Script)
════════════════════════════════════

  Local Machine                       AWS S3
  ─────────────                       ──────
  ┌──────────────┐                    ┌──────────────────┐
  │              │   upload_to_s3.sh  │                  │
  │  data/       │──────────────────▶│  weekly-data/    │
  │  *.csv       │   (aws s3 cp)     │  ├── file1.csv   │
  │              │                    │  ├── file2.csv   │
  └──────────────┘                    │  └── file3.csv   │
                                      └──────────────────┘


PHASE 3: DATA LOADING (Snowflake SQL)
═══════════════════════════════════════

  AWS S3                            Snowflake
  ──────                            ─────────
  ┌──────────────────┐              ┌──────────────────────────┐
  │                  │  COPY INTO   │                          │
  │  s3://netflix_   │────────────▶│  RAW_WEEKLY_VIEWS        │
  │  2026/weekly-    │              │  (Staging Table)         │
  │  data/*.csv      │              │         │                │
  │                  │              │         │ INSERT INTO    │
  └──────────────────┘              │         │ (Transform)    │
                                    │         ▼                │
                                    │  NETFLIX_WEEKLY_VIEWS    │
                                    │  (Production Table)      │
                                    │         │                │
                                    │         │ Analysis       │
                                    │         ▼                │
                                    │  ┌──────────────────┐    │
                                    │  │  Queries &       │    │
                                    │  │  Reports         │    │
                                    │  └──────────────────┘    │
                                    └──────────────────────────┘
```


## Security Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                         SECURITY MODEL                                    │
└────────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────┐     ┌─────────────────────┐     ┌──────────────────┐
  │                 │     │                     │     │                  │
  │  Developer      │────▶│  Terraform IAM      │────▶│  AWS S3 Bucket   │
  │  (AWS CLI)      │     │  Role (Full Access) │     │  (Encrypted)     │
  │                 │     │                     │     │                  │
  └─────────────────┘     └─────────────────────┘     └────────┬─────────┘
                                                                │
                                                  Trust Policy  │  (sts:AssumeRole)
                                                                │
  ┌─────────────────┐     ┌─────────────────────┐              │
  │                 │     │                     │              │
  │  Snowflake      │────▶│  Snowflake IAM      │◀─────────────┘
  │  (Read Only)    │     │  Role (S3 Read)     │
  │                 │     │                     │
  └─────────────────┘     └─────────────────────┘

  Security Controls:
  ├── S3 Bucket: Encrypted (AES256), Public Access Blocked
  ├── IAM Role: Least Privilege (Read-Only), External ID Required
  ├── Snowflake: Storage Integration with Role ARN + External ID
  └── .gitignore: Secrets Never Committed to Git
```


## File Structure Diagram

```
netflix-pipeline/
├── README.md                          # Project overview & quick start
├── .gitignore                         # Keeps secrets out of Git
│
├── terraform/                         # Infrastructure as Code
│   ├── providers.tf                   # AWS provider configuration
│   ├── variables.tf                   # All configurable inputs
│   ├── main.tf                        # S3 bucket + IAM role
│   ├── outputs.tf                     # Values printed after apply
│   └── terraform.tfvars.example       # Template for variable values
│
├── sql/                               # Snowflake SQL Scripts
│   ├── 01_create_database_and_schema.sql
│   ├── 02_create_tables.sql
│   ├── 03_create_storage_integration_and_stage.sql
│   ├── 04_load_data.sql
│   └── 05_analysis_queries.sql
│
├── scripts/                           # Automation Scripts
│   └── upload_to_s3.sh               # Upload CSV files to S3
│
├── data/                              # Local CSV files (not in Git)
│   └── *.csv                          # Netflix weekly data files
│
└── docs/                              # Documentation
    ├── architecture.md                # This file
    └── project-structure.md           # Detailed folder breakdown
```
