#!/usr/bin/env bash
# Episode 4: did each pod in this lab end up where the lab left it?
set -uo pipefail
cd "$(dirname "$0")" || exit 1
# shellcheck source=SCRIPTDIR/../../scripts/lib.sh
source ../../scripts/lib.sh

echo "Episode 4: Pods in Depth"
echo

# Called from inside the check strings below, which lib.sh runs with eval.
# shellcheck disable=SC2329
field() { kubectl get pod "$1" -o jsonpath="$2" 2>/dev/null; }

check "kubectl is pointed at the series cluster (kind-unlocked)" \
  "[ \"\$(kubectl config current-context 2>/dev/null)\" = kind-unlocked ] && kubectl get nodes" \
  "run: kubectl config use-context kind-unlocked"

check "web is Running, with the pinned nginx image" \
  "[ \"\$(field web '{.status.phase}')\" = Running ] && field web '{.spec.containers[0].image}' | grep -q '@sha256:0985e772'" \
  "run: kubectl apply -f manifests/web.yaml"

check "succeeds finished with phase Succeeded" \
  "[ \"\$(field succeeds '{.status.phase}')\" = Succeeded ]" \
  "run: kubectl apply -f manifests/run-once.yaml, then wait 10 seconds"

check "fails finished with phase Failed and exit code 3" \
  "[ \"\$(field fails '{.status.phase}')\" = Failed ] && [ \"\$(field fails '{.status.containerStatuses[0].state.terminated.exitCode}')\" = 3 ]" \
  "run: kubectl apply -f manifests/run-once.yaml, then wait 10 seconds"

check "web-init: the init container finished, and nginx serves the page it wrote" \
  "[ \"\$(field web-init '{.status.initContainerStatuses[0].state.terminated.exitCode}')\" = 0 ] && kubectl exec web-init -c nginx -- wget -qO- localhost 2>/dev/null | grep -q 'Written by an init container'" \
  "run: kubectl apply -f manifests/web-init.yaml, then wait 15 seconds"

check "sidecar: log-shipper is a native sidecar, running, and READY is 2/2" \
  "[ \"\$(field sidecar '{.spec.initContainers[0].restartPolicy}')\" = Always ] && [ \"\$(field sidecar '{.status.initContainerStatuses[0].started}')\" = true ] && [ \"\$(kubectl get pod sidecar --no-headers 2>/dev/null | awk '{print \$2}')\" = 2/2 ]" \
  "run: kubectl apply -f manifests/sidecar.yaml"

check "api is fixed: Running, no restarts, and connected" \
  "[ \"\$(field api '{.status.phase}')\" = Running ] && [ \"\$(field api '{.status.containerStatuses[0].restartCount}')\" = 0 ] && kubectl logs api 2>/dev/null | grep -q 'connected to'" \
  "run: kubectl replace --force -f manifests/api-fixed.yaml"

check "web-init-broken is gone or fixed" \
  "! kubectl get pod web-init-broken >/dev/null 2>&1 || [ \"\$(field web-init-broken '{.status.phase}')\" = Running ]" \
  "run: kubectl delete -f manifests/web-init-broken.yaml"

summary
