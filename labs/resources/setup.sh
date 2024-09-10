#!/bin/bash
# ./setup.sh cluster 1.29 us-west-1 minimal
# ./setup.sh managed-nodegroup 1.29 us-west-1 minimal on-demand m5.large
# ./setup.sh nodegroup 1.29 us-west-1 minimal on-demand m5.large

case "$1" in
    cluster)
        "$PWD"/scripts/setup-cluster.sh "$2" "$3" "$4"
        ;;
    managed-nodegroup)
        # TODO: Setup for EKS nodegroup
        "$PWD"/scripts/setup-managed-nodegroup.sh "$2" "$3" "$4" "$5" "$6"
        ;;
    nodegroup)
        # TODO: Setup for EKS nodegroup
        "$PWD"/scripts/setup-nodegruop.sh "$2" "$3" "$4" "$5" "$6"
        ;;
    *)
        echo "Invalid setup."
        ;;
esac

