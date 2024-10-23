#!/bin/bash

# Check if at least one argument is provided
if [ $# -eq 0 ]; then
    echo "No arguments provided. Using default values."
else
    # Set EKS_CLUSTER_NAME if provided
    if [ "$1" != "" ]; then
        EKS_CLUSTER_NAME="$(echo "$1" | sed 's/^/EKS-Lab-/; s/\./-/')"
    fi

    # Set EKS_CLUSTER_REGION if provided
    if [ "$2" != "" ]; then
        EKS_CLUSTER_REGION="$2"
    fi
     # Set CLUSTER_CONFIG if provided
    if [ "$3" != "" ]; then
        case "$3" in
            full)
                CLUSTER_CONFIG="full"
                ;;
            minimal)
                CLUSTER_CONFIG="minimal"
                ;;
            ipv6)
                CLUSTER_CONFIG="ipv6"
                ;;
            private)
                CLUSTER_CONFIG="private"
                ;;
            *)
                echo "Invalid cluster configuration option. Using default."
                CLUSTER_CONFIG="minimal"
                ;;
        esac
    fi
fi

# Get AZs for the specified region in the desired format
AZ_ARRAY=$(aws ec2 describe-availability-zones \
    --region "$EKS_CLUSTER_REGION" \
    --query 'AvailabilityZones[?State==`available`].ZoneName' \
    --output json | sed 's/\[/["/;s/\]/"]/' | sed 's/,/", "/g' | tr -d '\n\r\t ')

# Set default values if not provided
export EKS_CLUSTER_REGION=${EKS_CLUSTER_REGION:-"us-east-1"}
export EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME:-"EKS-Lab"}-${CLUSTER_CONFIG}
export CLUSTER_CONFIG=${CLUSTER_CONFIG:-"minimal"}
export CLUSTER_VERSION="${1:-1.30}"
export CLUSTER_FILE_LOCATION="$(echo "$CLUSTER_VERSION"| sed 's/\./-/')"

# TODO: fix the AZ list by comparing the AZ_ARRAY with non-supporting AZ for EKS
# Define the array to compare against
COMPARE_ARRAY='["us-east-1e", "eu-west-2"]'

# Update AZ_ARRAY by removing elements that exist in COMPARE_ARRAY
export AZ_ARRAY=$(echo "${AZ_ARRAY:-'["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]'}" |
                  sed 's/""/"/g' |
                  jq -c --argjson compare "$COMPARE_ARRAY" '
                    . | fromjson |
                    map(select(. as $item | $compare | index($item) | not)) |
                    tojson
                  ')

echo "Configuring cluster $EKS_CLUSTER_NAME in region $EKS_CLUSTER_REGION with AZs: $AZ_ARRAY"

# You can now use $AZ_ARRAY in your configuration where needed
# You could then use these AZs in your cluster configuration, for example:
# eksctl create cluster --name $EKS_CLUSTER_NAME --region $EKS_CLUSTER_REGION --zones ${AZ_ARRAY[0]},${AZ_ARRAY[1]},${AZ_ARRAY[2]}
