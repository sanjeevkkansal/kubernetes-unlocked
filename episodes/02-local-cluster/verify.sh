#!/usr/bin/env bash
# Episode 2: is the series cluster up, shaped right, and running work on both workers?
set -uo pipefail
cd "$(dirname "$0")" || exit 1
# shellcheck source=SCRIPTDIR/../../scripts/lib.sh
source ../../scripts/lib.sh

echo "Episode 2: Set Up a Local Cluster"
echo

# Called from inside the check strings below, which lib.sh runs with eval.
# shellcheck disable=SC2329
count() { kubectl get nodes --no-headers "$@" 2>/dev/null | wc -l | tr -d ' '; }
# shellcheck disable=SC2329
hello_nodes() {
  kubectl get pods -l app=hello --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null | sort -u | grep -c .
}

# shellcheck disable=SC2329
tools_ok() {
  command -v docker >/dev/null && command -v kind >/dev/null && command -v kubectl >/dev/null &&
    docker info >/dev/null 2>&1
}

check "docker, kind and kubectl are installed and Docker is running" \
  "tools_ok" \
  "run: docker version --format '{{.Server.Version}}'; kind version; kubectl version --client"

check "a kind cluster named 'unlocked' exists" \
  "kind get clusters | grep -qx unlocked" \
  "./cluster/up.sh from the repo root"

check "kubectl is pointed at it (context kind-unlocked)" \
  "[ \"\$(kubectl config current-context 2>/dev/null)\" = kind-unlocked ]" \
  "kubectl config use-context kind-unlocked"

check "it has 3 nodes" \
  "[ \"\$(count)\" = 3 ]" \
  "kind-config.yaml asks for 3. Delete and recreate: ./cluster/down.sh then ./cluster/up.sh"

check "1 control plane and 2 workers" \
  "[ \"\$(count -l node-role.kubernetes.io/control-plane)\" = 1 ] && [ \"\$(count -l '!node-role.kubernetes.io/control-plane')\" = 2 ]" \
  "you may be on a different cluster; check the context"

check "all nodes are Ready" \
  "[ \"\$(count)\" -gt 0 ] && [ \"\$(kubectl get nodes --no-headers | grep -vc ' Ready ')\" = 0 ]" \
  "a stopped node? 'docker ps -a' and 'docker start <name>'"

check "every node runs Kubernetes v1.37" \
  "[ \"\$(count)\" -gt 0 ] && [ \"\$(kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' | tr ' ' '\n' | grep -vc '^v1\.37\.')\" = 0 ]" \
  "the cluster was made from a different node image. Recreate it with ./cluster/up.sh"

check "the system pods in kube-system are Running" \
  "[ \"\$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c ' Running ')\" -gt 0 ] && [ \"\$(kubectl get pods -n kube-system --no-headers | grep -vc ' Running ')\" = 0 ]" \
  "kubectl get pods -n kube-system, then describe the one that is not Running"

check "the hello Deployment has 4 ready replicas" \
  "[ \"\$(kubectl get deploy hello -o jsonpath='{.status.readyReplicas}' 2>/dev/null)\" = 4 ]" \
  "kubectl apply -f manifests/hello-deployment.yaml"

check "its pods run on more than one node" \
  "[ \"\$(hello_nodes)\" -ge 2 ]" \
  "after a node outage pods stay where they were moved: kubectl rollout restart deployment/hello"

summary
