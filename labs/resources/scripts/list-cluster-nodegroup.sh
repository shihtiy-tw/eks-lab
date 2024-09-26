#!/bin/bash

# Define color codes
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)

# Get all contexts
contexts=$(kubectl config get-contexts -o name)

# Read contexts into an array
IFS=$'\n' read -d '' -r -a context_array <<< "$contexts"

for context in "${context_array[@]}"; do
    echo "${BLUE}Context: $context${RESET}"

    # Switch to the context
    kubectl config use-context "$context" > /dev/null

    # Get the region from the cluster name
    region=$(echo "$cluster_name" | awk -F'.' '{print $4}')
    cluster_name=$(echo "$context" | awk -F: '{split($NF,a,"/"); print a[2]}')
    region=$(echo "$context" | awk -F: '{print $4}')

    echo "${GREEN}Cluster: $cluster_name${RESET}"
    echo "${GREEN}Region: $region${RESET}"

    # Check if the cluster still exist
    cluster=$(eksctl get cluster --name "$cluster_name" --region "$region" --output json 2>/dev/null | jq -r '.[].Name')

    if [ "$cluster" = "" ]; then
      echo "${RED}$cluster_name is not found. Removing the context...${RESET}"
      kubectl config delete-context "$context"
      continue
    fi

    # List node groups for the current cluster
    nodegroups=$(eksctl get nodegroup --cluster "$cluster_name" --region "$region" --output json 2>/dev/null | jq -r '.[].Name')

    if [ "$nodegroups" = "" ]; then
        echo "${RED}No node groups found for this cluster.${RESET}"
    else
        echo "${YELLOW}Node Groups:${RESET}"
        while IFS= read -r nodegroup; do
            echo "  - $nodegroup"
        done <<< "$nodegroups"
    fi
    echo ""

done

# Switch back to the original context
original_context=$(kubectl config current-context)
kubectl config use-context "$original_context" > /dev/null
