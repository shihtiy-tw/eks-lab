#!/bin/bash

CURRENT_CONTEXT=$(kubectl config current-context)
EKS_CLUSTER_NAME=$(echo "$CURRENT_CONTEXT" | awk -F: '{split($NF,a,"/"); print a[2]}')
AWS_REGION=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $4}')
AWS_ACCOUNT_ID=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $5}')
POLICY_NAME=eks-fargate-logging-policy-opensearch
POLICY_URL=https://raw.githubusercontent.com/aws-samples/amazon-eks-fluent-logging-examples/mainline/examples/fargate/amazon-elasticsearch/permissions.json

ROLE_NAME="$(eksctl get fargateprofile --cluster "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --output json | jq -r '.[0].podExecutionRoleARN | split("/") | last')"

echo -e "${YELLOW}Step 3: Creating IAM policy...${NC}"
if ! aws iam list-policies --query "Policies[].[PolicyName,UpdateDate]" --output text | grep "$IAM_POLICY_NAME"; then
  if aws iam create-policy --policy-name "$IAM_POLICY_NAME" --policy-document file://policy.json; then
    echo -e "${GREEN}IAM policy created successfully.\n${NC}"
  else
    echo -e "${RED}Failed to create IAM policy.${NC}"
    exit 0
  fi
else
  echo -e "${GREEN}IAM policy already exists.\n${NC}"
fi


curl -O "$POLICY_URL"

aws iam create-policy --policy-name "$POLICY_NAME" --policy-document file://permissions.json

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::"$AWS_ACCOUNT_ID":policy/"$POLICY_NAME" \
  --role-name "$ROLE_NAME"

# TODO: need to make sure the log is written to the opensearch cluster
export TF_VAR_EKSCLUSTER=$EKS_CLUSTER_NAME
terraform apply

# TODO: configmap for opensearch logging

# export INDEX
# export HOST
# export TYPE
# export REGION
# envsubst < k8s-configmap-logging-opensearch.yaml | kubectl apply -f -

# TODO: add fargate role to the opensearch access
