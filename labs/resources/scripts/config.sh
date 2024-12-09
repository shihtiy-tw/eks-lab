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
            auto)
                CLUSTER_CONFIG="auto"
                ;;
            # ipv6)
            #     CLUSTER_CONFIG="ipv6"
            #     ;;
            # private)
            #     CLUSTER_CONFIG="private"
            #     ;;
            *)
                echo "Invalid cluster configuration option. Exit the script. Please check if the cluster config is created or setup."
                exit
                ;;
        esac
    fi
fi

# Get AZs for the specified region in the desired format
# AZ_ARRAY=$(aws ec2 describe-availability-zones \
#     --region "$EKS_CLUSTER_REGION" \
#     --query 'AvailabilityZones[?State==`available`].ZoneName' \
#     --output json | sed 's/\[/["/;s/\]/"]/' | sed 's/,/", "/g' | tr -d '\n\r\t ')

# Set default values if not provided
export EKS_CLUSTER_REGION=${EKS_CLUSTER_REGION:-"us-east-1"}
export EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME:-"EKS-Lab"}-${CLUSTER_CONFIG}
export CLUSTER_CONFIG=${CLUSTER_CONFIG:-"minimal"}
export CLUSTER_VERSION="${1:-1.30}"
export CLUSTER_FILE_LOCATION="$(echo "$CLUSTER_VERSION"| sed 's/\./-/')"

echo "Configuring cluster $EKS_CLUSTER_NAME in region $EKS_CLUSTER_REGION with AZs: $AZ_ARRAY"
