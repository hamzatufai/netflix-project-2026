#!/bin/bash
# ============================================================
# upload_to_s3.sh — Upload CSV Data to S3
# Purpose: Upload Netflix CSV files from local machine to S3 bucket
# Teaching Note: This script validates files before uploading and
#   provides clear error messages if something goes wrong.
#
# Usage:
#   chmod +x scripts/upload_to_s3.sh
#   ./scripts/upload_to_s3.sh
#
# Prerequisites:
#   1. AWS CLI installed and configured (aws configure)
#   2. Terraform applied (terraform apply in terraform/ folder)
#   3. CSV file exists in the data/ folder
# ============================================================

# ---- Color Codes for Terminal Output ----
# WHY: Colored output makes it easier to spot errors vs success
RED='\033[0;31m'      # Red for errors
GREEN='\033[0;32m'    # Green for success
YELLOW='\033[1;33m'   # Yellow for warnings
NC='\033[0m'          # No Color (reset)

# ---- Configuration ----
BUCKET_NAME="netflix_2026"
S3_PREFIX="weekly-data"
LOCAL_DATA_DIR="../data"
AWS_REGION="us-east-1"

# ---- Function: Print Section Header ----
print_header() {
    echo ""
    echo -e "${YELLOW}============================================${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${YELLOW}============================================${NC}"
}

# ---- Function: Check if command exists ----
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}ERROR: '$1' is not installed.${NC}"
        echo "Please install it first:"
        echo "  - AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
}

# ============================================================
# STEP 1: Pre-flight Checks
# ============================================================
print_header "STEP 1: Checking prerequisites"

# Check AWS CLI is installed
check_command "aws"
echo -e "${GREEN}✓ AWS CLI is installed${NC}"

# Check AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}ERROR: AWS credentials not configured.${NC}"
    echo "Run: aws configure"
    echo "You'll need your AWS Access Key ID and Secret Access Key."
    exit 1
fi
echo -e "${GREEN}✓ AWS credentials are configured${NC}"

# Check if bucket exists
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${RED}ERROR: Bucket '$BUCKET_NAME' does not exist.${NC}"
    echo "Run 'terraform apply' in the terraform/ folder first."
    exit 1
fi
echo -e "${GREEN}✓ S3 bucket '$BUCKET_NAME' exists${NC}"

# Check if data directory exists
if [ ! -d "$LOCAL_DATA_DIR" ]; then
    echo -e "${RED}ERROR: Data directory '$LOCAL_DATA_DIR' not found.${NC}"
    echo "Create it and add your CSV files:"
    echo "  mkdir -p data"
    echo "  cp /path/to/your/csv files data/"
    exit 1
fi

# Check for CSV files
CSV_COUNT=$(find "$LOCAL_DATA_DIR" -name "*.csv" -type f | wc -l)
if [ "$CSV_COUNT" -eq 0 ]; then
    echo -e "${RED}ERROR: No CSV files found in '$LOCAL_DATA_DIR'.${NC}"
    echo "Add your Netflix CSV files there first."
    exit 1
fi
echo -e "${GREEN}✓ Found $CSV_COUNT CSV file(s) to upload${NC}"

# ============================================================
# STEP 2: Validate CSV Format
# ============================================================
print_header "STEP 2: Validating CSV format"

# Check header row of first CSV file
FIRST_CSV=$(find "$LOCAL_DATA_DIR" -name "*.csv" -type f | head -1)
EXPECTED_HEADER="week,category,weekly_rank,show_title,season_title,weekly_hours_viewed,runtime,weekly_views,cumulative_weeks_in_top_10"

ACTUAL_HEADER=$(head -1 "$FIRST_CSV" | tr -d '\r')
# WHY: tr -d '\r' removes Windows line endings (carriage return)

if [ "$ACTUAL_HEADER" = "$EXPECTED_HEADER" ]; then
    echo -e "${GREEN}✓ CSV header matches expected format${NC}"
else
    echo -e "${YELLOW}⚠ WARNING: CSV header may not match expected format${NC}"
    echo "  Expected: $EXPECTED_HEADER"
    echo "  Found:    $ACTUAL_HEADER"
    echo ""
    echo "The upload will continue, but data loading in Snowflake may fail."
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Upload cancelled."
        exit 1
    fi
fi

# ============================================================
# STEP 3: Upload to S3
# ============================================================
print_header "STEP 3: Uploading files to S3"

# Upload with progress tracking
# WHY: --recursive uploads all files in the directory
# WHY: --only-show-errors suppresses verbose output (cleaner terminal)
# WHY: --exclude "*/*.csv" + --include "*.csv" ensures only CSVs are uploaded
aws s3 cp "$LOCAL_DATA_DIR/" "s3://$BUCKET_NAME/$S3_PREFIX/" \
    --recursive \
    --include "*.csv" \
    --region "$AWS_REGION"

# ---- Check upload result ----
UPLOAD_EXIT_CODE=$?

if [ $UPLOAD_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ All files uploaded successfully!${NC}"
else
    echo -e "${RED}ERROR: Upload failed with exit code $UPLOAD_EXIT_CODE${NC}"
    echo "Check your AWS permissions and network connection."
    exit 1
fi

# ============================================================
# STEP 4: Verify Upload
# ============================================================
print_header "STEP 4: Verifying upload"

# List files in S3 to confirm
echo "Files in s3://$BUCKET_NAME/$S3_PREFIX/:"
aws s3 ls "s3://$BUCKET_NAME/$S3_PREFIX/" --human-readable --summarize

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  UPLOAD COMPLETE!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Go to Snowflake console"
echo "  2. Run sql/03_create_storage_integration_and_stage.sql"
echo "  3. Run sql/04_load_data.sql"
echo ""
echo "To verify in Snowflake, run:"
echo "  LIST @netflix_s3_stage;"
echo ""
