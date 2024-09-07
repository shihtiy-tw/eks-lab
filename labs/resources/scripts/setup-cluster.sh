#!/bin/bash
# source $(pwd)/../config.sh 1.29 us-east-1 full

source $(pwd)/scripts/config.sh $1 $2 $3
source $(pwd)/config/.env

export CLUSTER_FILE_LOCATION="$(echo $1| sed 's/\./-/')"
export CLUSTER_FILE="$(pwd)/versions/$(echo $CLUSTER_FILE_LOCATION)/${EKS_CLUSTER_NAME}-${EKS_CLUSTER_REGION}.yaml"

# ANSI color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

printf "${BLUE}EKS Cluster Configuration Summary:\n"
printf "${BLUE}--------------------------------${NC}\n"
printf "${GREEN}%-20s${NC}%s\n" "Cluster Name:" "${EKS_CLUSTER_NAME}"
printf "${GREEN}%-20s${NC}%s\n" "Cluster Version:" "${CLUSTER_VERSION}"
printf "${GREEN}%-20s${NC}%s\n" "Region:" "${EKS_CLUSTER_REGION}"
printf "${GREEN}%-20s${NC}%s\n" "Availability Zones:" "${AZ_ARRAY}"
printf "${GREEN}%-20s${NC}%s\n" "IAM User:" "${IAM_USER}"
printf "${GREEN}%-20s${NC}%s\n" "Secret Key ARN:" "${SECRET_KEY_ARN}"
printf "${GREEN}%-20s${NC}%s\n" "Cluster Config:" "${CLUSTER_CONFIG}"
printf "${GREEN}%-20s${NC}%s\n" "Cluster YAML File:" "${CLUSTER_FILE}"
printf "${BLUE}--------------------------------${NC}\n"


cat $(pwd)/clusters/cluster-${CLUSTER_CONFIG}.yaml | envsubst '${EKS_CLUSTER_NAME},${EKS_CLUSTER_REGION},${AZ_ARRAY},${IAM_USER},${SECRET_KEY_ARN}' > ${CLUSTER_FILE}