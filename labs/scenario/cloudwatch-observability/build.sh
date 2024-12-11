#!/usr/bin/env bash

# Environment Variables
# Get the current context and extract information
CURRENT_CONTEXT=$(kubectl config current-context)
EKS_CLUSTER_NAME=$(echo "$CURRENT_CONTEXT" | awk -F: '{split($NF,a,"/"); print a[2]}')
AWS_REGION=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $4}')
AWS_ACCOUNT_ID=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $5}')
ADDON_NAME="amazon-cloudwatch-observability"

aws eks update-addon \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --addon-name "$ADDON_NAME" \
    --configuration-values 'file://disk-memory.json' \
    --resolve-conflicts PRESERVE \
    --region "$AWS_REGION"
