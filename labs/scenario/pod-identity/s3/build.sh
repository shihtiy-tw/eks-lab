#!/bin/bash

# Environment Variables
# Get the current context and extract information
CURRENT_CONTEXT=$(kubectl config current-context)
EKS_CLUSTER_NAME=$(echo "$CURRENT_CONTEXT" | awk -F: '{split($NF,a,"/"); print a[2]}')
AWS_REGION=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $4}')
AWS_ACCOUNT_ID=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $5}')

NAMESPACE=pod-identity
SERVICE_ACCOUNT_NAME=s3-reader

POLICY_NAME=s3_policy
POLICY_FILE=s3-policy.json
ROLE_NAME=s3_reader
ROLE_DESCRIPTION="s3 reader"

aws iam create-policy \
  --policy-name "$POLICY_NAME" \
  --policy-document file://"$POLICY_FILE"

kubectl apply -f k8s-serviceaccount.yaml

aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file://trust-relationship.json \
  --description "$ROLE_DESCRIPTION"


aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn=arn:aws:iam::"$AWS_ACCOUNT_ID":policy/"$POLICY_NAME"

aws iam create-policy-version  \
    --policy-arn=arn:aws:iam::"$AWS_ACCOUNT_ID":policy/"$POLICY_NAME" \
    --policy-document file://"$POLICY_FILE" \
    --set-as-default \


aws eks create-pod-identity-association \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --role-arn arn:aws:iam::"$AWS_ACCOUNT_ID":role/"$ROLE_NAME" \
  --namespace "$NAMESPACE" \
  --service-account "$SERVICE_ACCOUNT_NAME"

aws iam get-role \
  --role-name "$ROLE_NAME" \
  --query Role.AssumeRolePolicyDocument

aws iam list-attached-role-policies \
  --role-name "$ROLE_NAME" \
  --query AttachedPolicies[].PolicyArn \
  --output text


kubectl apply -f k8s-deployment.yaml

