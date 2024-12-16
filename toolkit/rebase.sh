#!/bin/bash

# Fetch the latest changes from the remote repository
git fetch --prune

# Get a list of all the local branches that start with "feature/"
readarray -t feature_branches < <(git branch --list "feature/*" | sed 's/^ *//g')

# Rebase each feature branch on the "develop" branch
for branch in "${feature_branches[@]}"; do
    echo "Rebasing branch '$branch' on 'develop'..."
    git checkout "$branch"
    git rebase "develop"
    if [ $? -ne 0 ]; then
        echo "Rebase failed for branch '$branch'. Please resolve the conflicts and continue the rebase."
        exit 1
    fi
    git push --force-with-lease
done

git checkout develop
