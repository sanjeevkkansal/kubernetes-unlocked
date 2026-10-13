# Episode 3 solution: deleting a static pod

```bash
kubectl delete pod -n kube-system kube-scheduler-unlocked-control-plane
```

The command may wait, and if you look from a second terminal the pod shows `Terminating`.
Within a few seconds to a couple of minutes (it varied between our runs) it is back, with a new
age:

```bash
kubectl get pods -n kube-system
```

```
NAME                                    READY   STATUS    RESTARTS        AGE
...
kube-scheduler-unlocked-control-plane   1/1     Running   1 (3m23s ago)   10s
```

Now look at the container on the node:

```bash
docker exec unlocked-control-plane crictl ps --name kube-scheduler
```

Its CREATED column says it was started minutes before you ran the delete. It never stopped.

Why: a static pod is defined by a file in `/etc/kubernetes/manifests`, and the kubelet runs it
from that file. The pod you see through kubectl is a mirror the kubelet publishes so the API
server can show it. Deleting the mirror deletes only that record; the kubelet publishes it again.
The file is the source of truth, which is why the break-it steps move the file.

You can see where a pod comes from:

```bash
kubectl get pod -n kube-system kube-scheduler-unlocked-control-plane \
  -o jsonpath='{.metadata.annotations.kubernetes\.io/config\.source}{"\n"}'
```

```
file
```
