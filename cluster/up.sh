#!/usr/bin/env bash
# Create the local cluster used by every lab: one control plane, two workers.
set -euo pipefail
cd "$(dirname "$0")"

for tool in docker kind kubectl; do
  command -v "$tool" >/dev/null || { echo "missing: $tool (see the README prerequisites)"; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "Docker is installed but not running. Start it and try again."; exit 1; }

if kind get clusters 2>/dev/null | grep -qx unlocked; then
  echo "Cluster 'unlocked' already exists."
else
  kind create cluster --config kind-config.yaml
fi

kubectl config use-context kind-unlocked >/dev/null
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl get nodes
