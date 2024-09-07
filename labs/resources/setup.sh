#!/bin/bash
# ./setup.sh cluster 1.29 us-west-1 minimal

case "$1" in
    cluster)
        $(pwd)/scripts/setup-cluster.sh $2 $3 $4
        ;;
    node)
        # TODO
        # Setup for EKS nodegroup
        # $(pwd)/scripts/setup-node.sh $2 $3 $4
        ;;
    *)
        echo "Invalid setup."
        ;;
esac

