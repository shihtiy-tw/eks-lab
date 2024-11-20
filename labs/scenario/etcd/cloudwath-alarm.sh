#!/bin/bash


# Environment Variables
# Get the current context and extract information
CURRENT_CONTEXT=$(kubectl config current-context)
EKS_CLUSTER_NAME=$(echo "$CURRENT_CONTEXT" | awk -F: '{split($NF,a,"/"); print a[2]}')
AWS_REGION=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $4}')
AWS_ACCOUNT_ID=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $5}')

# Provided by my colleage Yadav
aws cloudwatch put-metric-alarm \
  --alarm-name "EKS-ETCD-Storage-Size-Alarm" \
  --alarm-description "Alarm when ETCD storage size exceeds 6GB" \
  --metric-name "apiserver_storage_size_bytes" \
  --namespace "ContainerInsights" \
  --statistic "Maximum" \
  --period 60 \
  --threshold 6000000000 \
  --comparison-operator "GreaterThanThreshold" \
  --dimensions Name=ClusterName,Value="$EKS_CLUSTER_NAME" \
  --evaluation-periods 3 \
  --alarm-actions "arn:aws:sns:$AWS_REGION:$AWS_ACCOUNT_ID:<sns-name>" \
  --unit "Bytes" \
  --region "$AWS_REGION"
