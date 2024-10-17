# Define color codes
GREEN=\033[0;32m
YELLOW=\033[0;33m
BLUE=\033[0;34m
PURPLE=\033[0;35m
CYAN=\033[0;36m
RESET=\033[0m

.PHONY: help
.PHONY: test
.PHONY: clean
.PHONY: all
.PHONY: default

default: help

# Target to list clusters and node groups
list:
		@bash $(PWD)/labs/resources/scripts/list-cluster-nodegroup.sh

# TODO: create cluster/nodegroup and integration

# Clean target (optional)
clean:
		@echo "Nothing to clean"
