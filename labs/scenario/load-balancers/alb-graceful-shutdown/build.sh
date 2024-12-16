#!/bin/bash

SERVICE_NAME=$(yq -r ".metadata.name" k8s-service.yaml)
NAME_PREFIX=$(yq -r ".namePrefix" kustomization.yaml)

kustomize build . \
  | sed -e "/annotations:/,/spec:/s/${SERVICE_NAME}/${NAME_PREFIX}${SERVICE_NAME}/g" \
  | kubectl apply -f -

# /annotations:/,/spec:/: This is the range pattern that tells sed to perform the substitution only between the "annotations:" and "spec:" lines.
