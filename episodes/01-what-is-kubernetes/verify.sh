#!/usr/bin/env bash
# Episode 1: did the Deployment reach the state you declared?
set -uo pipefail
cd "$(dirname "$0")" || exit 1
# shellcheck source=SCRIPTDIR/../../scripts/lib.sh
source ../../scripts/lib.sh

echo "Episode 1: What Is Kubernetes"
echo

# Called from inside the check strings below, which lib.sh runs with eval.
# shellcheck disable=SC2329
desired() { kubectl get deploy nginx-deployment -o jsonpath='{.spec.replicas}' 2>/dev/null; }
# shellcheck disable=SC2329
ready()   { kubectl get deploy nginx-deployment -o jsonpath='{.status.readyReplicas}' 2>/dev/null; }

check "a cluster is reachable" \
  "kubectl get nodes" \
  "start one with ./cluster/up.sh from the repo root"

check "nginx-deployment exists" \
  "kubectl get deploy nginx-deployment" \
  "kubectl apply -f manifests/nginx-deployment.yaml"

check "it asks for at least 3 replicas" \
  "[ \"\$(desired)\" -ge 3 ]" \
  "the manifest declares 3; you may have scaled it below that"

check "every replica it asks for is ready" \
  "[ -n \"\$(ready)\" ] && [ \"\$(ready)\" = \"\$(desired)\" ]" \
  "give it a few seconds, then 'kubectl get pods -l app=nginx'"

check "the pods with app=nginx are exactly the Deployment's pods" \
  "[ \"\$(kubectl get pods -l app=nginx --field-selector=status.phase=Running --no-headers | wc -l | tr -d ' ')\" = \"\$(desired)\" ]" \
  "another pod carries the app=nginx label, or pods are still starting"

check "nginx answers inside the pods" \
  "kubectl exec deploy/nginx-deployment -- wget -qO- http://localhost | grep -q 'Welcome to nginx'" \
  "'kubectl logs deploy/nginx-deployment' shows what the server is doing"

check "the image is the pinned one from the manifest" \
  "kubectl get deploy nginx-deployment -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -q '@sha256:0985e772'" \
  "re-apply manifests/nginx-deployment.yaml"

summary
