#!/bin/bash
# ./setup.sh cluster 1.29 us-west-1 minimal
# ./setup.sh managed-nodegroup 1.29 us-west-1 minimal on-demand m5.large
# ./setup.sh managed-nodegroup 1.29 us-west-1 minimal custom-ami m5.large
# ./setup.sh nodegroup 1.29 us-west-1 minimal on-demand m5.large

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print usage
print_usage() {
    echo -e "${BLUE}Usage: $0 <command> [options]${NC}"
    echo
    echo -e "${GREEN}Commands:${NC}"
    echo -e "  ${YELLOW}cluster${NC} <version> <region> <mode>              Setup EKS cluster"
    echo -e "  ${YELLOW}managed-nodegroup${NC} <version> <region> <mode> <capacity-type> <instance-type>   Setup EKS managed nodegroup"
    echo -e "  ${YELLOW}nodegroup${NC} <version> <region> <mode> <capacity-type> <instance-type>           Setup EKS self-managed nodegroup"
    echo
    echo -e "${GREEN}Examples:${NC}"
    echo -e "  ${BLUE}$0 cluster 1.29 us-west-1 minimal${NC}"
    echo -e "  ${BLUE}$0 managed-nodegroup 1.29 us-west-1 minimal on-demand m5.large${NC}"
    echo -e "  ${BLUE}$0 nodegroup 1.29 us-west-1 minimal on-demand m5.large${NC}"
}

# Check if no arguments were provided
if [ $# -eq 0 ]; then
    print_usage
    exit 1
fi

case "$1" in
    cluster)
        echo -e "${GREEN}Setting up EKS cluster...${NC}"
        "$PWD"/scripts/setup-cluster.sh "$2" "$3" "$4"
        ;;
    managed-nodegroup)
        echo -e "${GREEN}Setting up EKS managed nodegroup...${NC}"
        "$PWD"/scripts/setup-managed-nodegroup.sh "$2" "$3" "$4" "$5" "$6"
        ;;
    nodegroup)
        echo -e "${GREEN}Setting up EKS self-managed nodegroup...${NC}"
        "$PWD"/scripts/setup-nodegruop.sh "$2" "$3" "$4" "$5" "$6"
        ;;
    *)
        echo -e "${RED}Invalid setup command: $1${NC}"
        print_usage
        exit 1
        ;;
esac
