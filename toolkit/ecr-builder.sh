#!/bin/bash
# reference: https://gist.github.com/vincentclaes/f587ba84bf116ed39d2841e49387f6c5
# Usage: ecr-builder <image name> <region>
# Example: ecr-builder java us-east-1

#!/bin/bash

# Define color codes for output formatting
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print timestamped messages
log_message() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Function to print success messages
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to print warning messages
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to print error messages
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check command status and print warning if failed
check_command() {
    if [ $? -ne 0 ]; then
        log_error "Command failed: $1"
        return 1
    fi
    return 0
}

# Get command line arguments
image_name=$1   # name of image
region=$2       # aws region e.g. us-east-1

# Validate input parameters
if [ "$image_name" = "" ] || [ "$region" = "" ]; then
    log_warning "Usage: $0 <image_name> <region>"
    exit 1
fi

log_message "Starting ECR helper script for image: $image_name in region: $region"

# Get AWS account ID
account=$(aws sts get-caller-identity --query Account --output text)
check_command "Failed to get AWS account ID" || exit 1

# Construct the full ECR repository URI
repository="${account}.dkr.ecr.${region}.amazonaws.com/${image_name}:latest"

# Step 1: Check if the ECR repository exists, create if it doesn't
log_message "Checking if repository exists in ECR..."
if ! aws ecr describe-repositories --repository-names "$image_name" > /dev/null 2>&1
then
    log_message "Repository does not exist. Creating..."
    aws ecr create-repository --repository-name "$image_name" > /dev/null
    check_command "Failed to create ECR repository" || exit 1
    log_success "Repository created successfully"
else
    log_message "Repository already exists"
fi

# Step 2: Authenticate Docker to ECR
log_message "Logging in to ECR..."
aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "$account.dkr.ecr.$region.amazonaws.com"
check_command "Failed to authenticate Docker to ECR" || exit 1
log_success "Successfully logged in to ECR"

# Step 3: Build the Docker image locally
log_message "Building Docker image locally..."
docker build -t "$image_name" .
check_command "Failed to build Docker image" || exit 1
log_success "Docker image built successfully"

# Step 4: Tag the Docker image for ECR
log_message "Tagging Docker image for ECR..."
docker tag "$image_name" "$repository"
check_command "Failed to tag Docker image" || exit 1
log_success "Docker image tagged successfully"

# Step 5: Push the Docker image to ECR
log_message "Pushing Docker image to ECR..."
docker push "$repository"
check_command "Failed to push Docker image to ECR" || exit 1
log_success "Docker image pushed to ECR successfully"

log_message "ECR helper script completed"
