# Episode 2 solution: a cluster with three workers

Copy `kind/single-node.yaml`, rename the cluster and add three `worker` nodes. The result is
[three-workers.yaml](three-workers.yaml).

```bash
kind create cluster --config solutions/three-workers.yaml
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl get nodes
```

```
node/big-control-plane condition met
node/big-worker condition met
node/big-worker2 condition met
node/big-worker3 condition met
NAME                STATUS   ROLES           AGE   VERSION
big-control-plane   Ready    control-plane   28s   v1.37.0
big-worker          Ready    <none>          13s   v1.37.0
big-worker2         Ready    <none>          13s   v1.37.0
big-worker3         Ready    <none>          13s   v1.37.0
```

kubectl now points at `kind-big`. Delete it and switch back to the series cluster:

```bash
kind delete cluster --name big
../../cluster/up.sh
```

```
Deleting cluster "big" ...
Deleted nodes: ["big-control-plane" "big-worker3" "big-worker" "big-worker2"]
Cluster 'unlocked' already exists.
...
```

Each extra worker is one more container, about 120 to 250 MB of memory when idle.
