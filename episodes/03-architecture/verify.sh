#!/usr/bin/env bash
# Episode 3: is every part of the cluster in place and working, and did the lab Deployment
# make it all the way through?
set -uo pipefail
cd "$(dirname "$0")" || exit 1
# shellcheck source=SCRIPTDIR/../../scripts/lib.sh
source ../../scripts/lib.sh

echo "Episode 3: Kubernetes Architecture"
echo

CP=unlocked-control-plane

# Called from inside the check strings below, which lib.sh runs with eval.
# shellcheck disable=SC2329
running_on_cp() {
  [ "$(kubectl get pod -n kube-system "$1-$CP" -o jsonpath='{.status.phase} {.spec.nodeName}' 2>/dev/null)" = "Running $CP" ]
}
# shellcheck disable=SC2329
ds_ready() { [ "$(kubectl get ds -n kube-system "$1" -o jsonpath='{.status.numberReady}' 2>/dev/null)" = 3 ]; }
# shellcheck disable=SC2329
web_running() { kubectl get pods -l app=web --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' '; }
# Exact commands that put back any control plane file moved out of the manifests folder.
fix_manifests() {
  local f out=""
  for f in etcd kube-apiserver kube-controller-manager kube-scheduler; do
    if ! docker exec "$CP" test -f "/etc/kubernetes/manifests/$f.yaml" 2>/dev/null; then
      out+="docker exec $CP mv /etc/kubernetes/$f.yaml /etc/kubernetes/manifests/  "
    fi
  done
  echo "${out:-nothing to put back}"
}
# shellcheck disable=SC2329
etcd_has_web() {
  kubectl exec -n kube-system "etcd-$CP" -- etcdctl \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    get /registry/deployments/default/web --keys-only 2>/dev/null | grep -qx /registry/deployments/default/web
}
# shellcheck disable=SC2329
manifests_in_place() {
  local f
  for f in etcd kube-apiserver kube-controller-manager kube-scheduler; do
    docker exec "$CP" test -f "/etc/kubernetes/manifests/$f.yaml" || return 1
  done
}
# shellcheck disable=SC2329
web_wanted() { kubectl get deploy web -o jsonpath='{.spec.replicas}' 2>/dev/null; }

check "kubectl is pointed at the series cluster (kind-unlocked)" \
  "[ \"\$(kubectl config current-context 2>/dev/null)\" = kind-unlocked ] && kubectl get nodes" \
  "../../cluster/up.sh from this folder"

check "all four control plane manifests are in place" \
  "manifests_in_place" \
  "a component is switched off. Run: $(fix_manifests)"

for c in kube-apiserver etcd kube-scheduler kube-controller-manager; do
  check "$c is Running on the control plane" \
    "running_on_cp $c" \
    "give it a few seconds after switching it on, then: kubectl get pods -n kube-system"
done

check "kube-proxy runs on all 3 nodes" "ds_ready kube-proxy" "kubectl get ds -n kube-system kube-proxy"
check "kindnet (the network plugin) runs on all 3 nodes" "ds_ready kindnet" "kubectl get ds -n kube-system kindnet"

check "the API server reports ready (/readyz)" \
  "[ \"\$(kubectl get --raw=/readyz 2>/dev/null)\" = ok ]" \
  "kubectl get --raw='/readyz?verbose' shows which check fails"

check "the web Deployment is stored in etcd" \
  "etcd_has_web" \
  "kubectl apply -f manifests/web.yaml"

check "every web pod it asks for is actually Running (counted, not read from its status)" \
  "[ -n \"\$(web_wanted)\" ] && [ \"\$(web_running)\" = \"\$(web_wanted)\" ]" \
  "if pods are missing, the controller manager may be off or still starting: wait 30 s"

check "every web pod was given a node by the scheduler" \
  "[ -z \"\$(kubectl get pods -l app=web -o jsonpath='{range .items[?(@.spec.nodeName==\"\")]}x{end}' 2>/dev/null)\" ] && [ -z \"\$(kubectl get pods -l app=web --field-selector=status.phase=Pending --no-headers 2>/dev/null)\" ]" \
  "Pending pods with no node: is the scheduler on? Run: $(fix_manifests)"

summary
