#!/bin/bash

# $ ./build.sh
# $ kustomize build . | kubectl delete -f -

SERVICE_NAME=$(yq -r ".metadata.name" k8s-service.yaml)
NAME_PREFIX=$(yq -r ".namePrefix" kustomization.yaml)

kustomize build . \
  | sed -e "/annotations:/,/spec:/s/${SERVICE_NAME}/${NAME_PREFIX}${SERVICE_NAME}/g" \
  | kubectl apply -f -
