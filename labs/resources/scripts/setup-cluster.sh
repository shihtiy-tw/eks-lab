#!/bin/bash
# source $(pwd)/../config.sh 1.29 us-east-1 full

source "$PWD"/scripts/config.sh "$1" "$2" "$3"
source "$PWD"/config/.env

export CLUSTER_FILE_LOCATION="$(echo "$1"| sed 's/\./-/')"
# TODO: change the eksctil file as eksctl-*.yaml for schema
export CLUSTER_FILE="$PWD/versions/$(echo "$CLUSTER_FILE_LOCATION")/${EKS_CLUSTER_NAME}-${EKS_CLUSTER_REGION}.yaml"

mkdir -p "$PWD/versions/""$(echo "$CLUSTER_FILE_LOCATION")"

# ANSI color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

printf "${BLUE}EKS Cluster Configuration Summary:\n"
printf "${BLUE}--------------------------------${NC}\n"
printf "${GREEN}%-20s${NC}%s\n" "Cluster Name:" "$EKS_CLUSTER_NAME"
printf "${GREEN}%-20s${NC}%s\n" "Cluster Version:" "$CLUSTER_VERSION"
printf "${GREEN}%-20s${NC}%s\n" "Region:" "$EKS_CLUSTER_REGION"
printf "${GREEN}%-20s${NC}%s\n" "Availability Zones:" "$AZ_ARRAY"
printf "${GREEN}%-20s${NC}%s\n" "IAM User:" "$IAM_USER"
printf "${GREEN}%-20s${NC}%s\n" "Secret Key ARN:" "$SECRET_KEY_ARN"
printf "${GREEN}%-20s${NC}%s\n" "Cluster Config:" "$CLUSTER_CONFIG"
printf "${GREEN}%-20s${NC}%s\n" "Cluster YAML File:" "$CLUSTER_FILE"
printf "${BLUE}--------------------------------${NC}\n"


cat "$PWD/clusters/eksctl-cluster-$CLUSTER_CONFIG".yaml | envsubst '${EKS_CLUSTER_NAME},${EKS_CLUSTER_REGION},${CLUSTER_VERSION},${AZ_ARRAY},${IAM_USER},${SECRET_KEY_ARN}' > "$CLUSTER_FILE"

# Capture both stdout and stderr, and store the exit status
printf "${BLUE}Validating the template...${NC}\n"
output=$(eksctl create cluster -f "$CLUSTER_FILE" --dry-run 2>&1)
exit_status=$?

# Check the exit status
if [ "$exit_status" -ne 0 ]; then
  echo -e "\n${RED}Template validation failed${NC}"
  # Print the captured output
  echo "$output"
else
  echo -e "\n${GREEN}Tempalte validation succeeded${NC}"
  echo -e "\n${GREEN}Executing eksctl command:${NC}"
  eksctl create cluster -f "$CLUSTER_FILE"
fi
