#!/bin/bash
# ./setup.sh managed-nodegroup 1.29 us-west-1 minimal on-demand m5.large

source "$PWD"/scripts/config.sh "$1" "$2" "$3"
source "$PWD"/config/.env


export NODEGROUP_CONFIG="${4:-on-demand}"
export NODEGROUP_SIZE="${5:-m5.large}"
export INSTANCE_TYPE="${NODEGROUP_SIZE//./}"

# TODO: change the eksctil file as eksctl-*.yaml for schema
export NODEGROUP_FILE="$PWD/versions/$(echo "$CLUSTER_FILE_LOCATION")/${EKS_CLUSTER_NAME}-${EKS_CLUSTER_REGION}-managed-nodegroup-${NODEGROUP_CONFIG}-${INSTANCE_TYPE}.yaml"

# ANSI color codes
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

if [[ $NODEGROUP_CONFIG = "custom-ami" ]]; then
  # custom ami name: "eks-lab-amazon-eks-arm64-1.29-20241023145809"
  export CUSTOM_AMI=$(aws ec2 describe-images \
    --filters "Name=name,Values=eks-lab*-1.29-*" "Name=state,Values=available" \
    --query 'Images[*].[ImageId,CreationDate]' \
    --output text \
    | sort -k2 -r \
    | head -n 1 \
    | awk '{print $1}')

  cat "$PWD/nodegroups/eksctl-managed-nodegroup-$NODEGROUP_CONFIG".yaml | envsubst '${EKS_CLUSTER_NAME},${CLUSTER_VERSION},${EKS_CLUSTER_REGION},${AZ_ARRAY},${NODEGROUP_CONFIG},${NODEGROUP_SIZE},${CUSTOM_AMI},${INSTANCE_TYPE}' > "$NODEGROUP_FILE"

elif [[ $NODEGROUP_CONFIG = "bottlerocket-userdata" ]]; then

  # https://github.com/bottlerocket-os/bottlerocket/blob/develop/QUICKSTART-EKS.md#cluster-info
  eksctl get cluster --region "$EKS_CLUSTER_REGION" --name "$EKS_CLUSTER_NAME" -o json \
   | jq --raw-output '.[] | "[settings.kubernetes]\napi-server = \"" + .Endpoint + "\"\ncluster-certificate =\"" + .CertificateAuthority.Data + "\"\ncluster-name = \"bottlerocket\""' > user-data.toml

  cat "$PWD/nodegroups/eksctl-managed-nodegroup-$NODEGROUP_CONFIG".yaml | envsubst '${EKS_CLUSTER_NAME},${CLUSTER_VERSION},${EKS_CLUSTER_REGION},${AZ_ARRAY},${NODEGROUP_CONFIG},${NODEGROUP_SIZE},${INSTANCE_TYPE}' > "$NODEGROUP_FILE"
else
  cat "$PWD/nodegroups/eksctl-managed-nodegroup-$NODEGROUP_CONFIG".yaml | envsubst '${EKS_CLUSTER_NAME},${CLUSTER_VERSION},${EKS_CLUSTER_REGION},${AZ_ARRAY},${NODEGROUP_CONFIG},${NODEGROUP_SIZE},${INSTANCE_TYPE}' > "$NODEGROUP_FILE"
fi

# envsubst '${EKS_CLUSTER_NAME},${CLUSTER_VERSION},${EKS_CLUSTER_REGION},${AZ_ARRAY},${NODEGROUP_CONFIG},${NODEGROUP_SIZE}' < $(pwd)/nodegroups/managed-nodegroup-${NODEGROUP_CONFIG}.yaml
#
printf "${BLUE}EKS Nodegroup Configuration Summary:\n"
printf "${BLUE}--------------------------------${NC}\n"
printf "${GREEN}%-20s${NC}%s\n" "Cluster Name:" "$EKS_CLUSTER_NAME"
printf "${GREEN}%-20s${NC}%s\n" "Cluster Version:" "$CLUSTER_VERSION"
printf "${GREEN}%-20s${NC}%s\n" "Region:" "$EKS_CLUSTER_REGION"
printf "${GREEN}%-20s${NC}%s\n" "Availability Zones:" "$AZ_ARRAY"
printf "${GREEN}%-20s${NC}%s\n" "Cluster Config:" "$CLUSTER_CONFIG"
printf "${GREEN}%-20s${NC}%s\n" "Nodegroup Config:" "$NODEGROUP_CONFIG"
printf "${GREEN}%-20s${NC}%s\n" "Nodegroup Size:" "$NODEGROUP_SIZE"
printf "${GREEN}%-20s${NC}%s\n" "Nodegroup YAML File:" "$NODEGROUP_FILE"
printf "${BLUE}--------------------------------${NC}\n"

# Capture both stdout and stderr, and store the exit status
printf "${BLUE}Validating the template...${NC}\n"
output=$(eksctl create nodegroup -f "$NODEGROUP_FILE" --dry-run 2>&1)
exit_status=$?

# Check the exit status
if [ "$exit_status" -ne 0 ]; then
  echo -e "\n${RED}Template validation failed${NC}"
  # Print the captured output
  echo "$output"
else
  echo -e "\n${GREEN}Tempalte validation succeeded${NC}"
  echo -e "\n${GREEN}Executing eksctl command:${NC}"
  eksctl create nodegroup -f "$NODEGROUP_FILE"
fi
