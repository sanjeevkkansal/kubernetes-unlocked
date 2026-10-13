# Episode 3: Kubernetes Architecture

Video: coming soon  |  Lab time: about 25 minutes

Phase 1: Foundations  |  Previous: [Episode 2](../02-local-cluster/)  |  Next: [Episode 4](../04-pods/)

## What you will be able to do

- Name the parts of the control plane (API server, etcd, scheduler, controller manager) and of
  each node (kubelet, container runtime, kube-proxy, network plugin), and say what each does.
- Find every one of them on your own cluster, and say which run as pods and which do not.
- Follow one `kubectl apply` through the cluster, using events as evidence.
- Predict what you will see when the scheduler or the controller manager is missing.

## Before you start

You need the cluster from [Episode 2](../02-local-cluster/). Run every command from this folder:

```bash
cd episodes/03-architecture
../../cluster/up.sh
```

Pod names (`web-5b55b57fbd-...`, `kindnet-99q55`) and ages will differ on your machine.
Everything else should match.

## The map

```
 control plane node                              worker nodes (x2)
 ┌─────────────────────────────────────┐         ┌──────────────────────────┐
 │ kube-apiserver   the only way in    │◀────────│ kubelet     runs pods    │
 │ etcd             stores everything  │         │ containerd  runs         │
 │ kube-scheduler   picks a node       │         │             containers   │
 │ kube-controller-manager             │         │ kube-proxy  Service      │
 │                  keeps desired state│         │             traffic      │
 │ kubelet, containerd, kube-proxy     │         │ kindnet     pod network  │
 └─────────────────────────────────────┘         └──────────────────────────┘
```

Everything talks to the API server, and only to the API server: the scheduler, the controller
manager, every kubelet, and you through kubectl. Only the API server talks to etcd. The parts never
call each other; each one watches the API server for its kind of work. The one time the API server
reaches out is to a kubelet, for `kubectl logs`, `exec` and `port-forward`.

---

## Step 1: find the control plane

The control plane runs as pods in the `kube-system` namespace (a namespace is a named group of
objects; a later episode covers them properly). `-n` picks the namespace:

```bash
kubectl get pods -n kube-system
```

```
NAME                                             READY   STATUS    RESTARTS   AGE
coredns-559f6c778d-hs2vk                         1/1     Running   0          130m
coredns-559f6c778d-kk6s9                         1/1     Running   0          130m
etcd-unlocked-control-plane                      1/1     Running   0          130m
kindnet-99q55                                    1/1     Running   0          130m
kindnet-ptfvr                                    1/1     Running   0          130m
kindnet-wbmwl                                    1/1     Running   0          130m
kube-apiserver-unlocked-control-plane            1/1     Running   0          130m
kube-controller-manager-unlocked-control-plane   1/1     Running   0          79m
kube-proxy-m545g                                 1/1     Running   0          130m
kube-proxy-nnmrj                                 1/1     Running   0          130m
kube-proxy-tt99z                                 1/1     Running   0          130m
kube-scheduler-unlocked-control-plane            1/1     Running   0          81m
```

Which node is each one on? `-o wide` adds a NODE column, along with IP and three more columns,
which makes a very wide table. `-o custom-columns` prints only the columns you name, each as
`HEADER:path`, where the path points into the pod's details (you will see those details in full
in the next episode). The trailing `\` continues the command on the next line:

```bash
kubectl get pods -n kube-system \
  -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```

```
NAME                                             NODE
coredns-559f6c778d-hs2vk                         unlocked-control-plane
coredns-559f6c778d-kk6s9                         unlocked-control-plane
etcd-unlocked-control-plane                      unlocked-control-plane
kindnet-99q55                                    unlocked-worker
kindnet-ptfvr                                    unlocked-control-plane
kindnet-wbmwl                                    unlocked-worker2
kube-apiserver-unlocked-control-plane            unlocked-control-plane
kube-controller-manager-unlocked-control-plane   unlocked-control-plane
kube-proxy-m545g                                 unlocked-control-plane
kube-proxy-nnmrj                                 unlocked-worker2
kube-proxy-tt99z                                 unlocked-worker
kube-scheduler-unlocked-control-plane            unlocked-control-plane
```

What just happened: the four control plane parts each run as one pod on the control-plane node,
named after it. kube-proxy and kindnet run one copy on every node. CoreDNS, the cluster's DNS
server, runs two copies; it gets its own episode later.

---

## Step 2: inside the control-plane node

Who started the API server? There is no Deployment for it, and it cannot be the API server's own
job, because it is not running yet. The control plane starts itself like this:

1. The node boots, and systemd starts the **kubelet**: a normal service on the machine, not a pod.
2. The kubelet reads the folder `/etc/kubernetes/manifests` and runs every pod file in it: etcd,
   the API server, the scheduler and the controller manager. These are **static pods**.
3. The API server connects to etcd. The scheduler and controller manager connect to the API server.
4. The kubelet registers its node with the API server, and the cluster can take your work.

The files involved, on the control-plane node:

| Path | What it is |
|------|------------|
| `/etc/kubernetes/manifests/` | static pod files, read by the kubelet |
| `/etc/kubernetes/pki/` | certificates: how the parts prove who they are (`pki/etcd/` is etcd's own) |
| `/etc/kubernetes/*.conf` | how each part reaches the API server (`scheduler.conf`, `controller-manager.conf`, `kubelet.conf`) |
| `/var/lib/kubelet/config.yaml` | the kubelet's settings, including where static pods live |
| `/var/lib/etcd/` | etcd's data on disk |

The control-plane node is a Docker container, so you can open a shell on it, as if you had logged
in to the machine:

```bash
docker exec -it unlocked-control-plane bash
```

`docker exec -it` runs a command inside a container with an interactive terminal; `bash` is the
command. Your prompt changes to `root@unlocked-control-plane:/#`. Now, on the node:

```bash
ls /etc/kubernetes
grep staticPodPath /var/lib/kubelet/config.yaml
ls /etc/kubernetes/manifests
head -14 /etc/kubernetes/manifests/kube-scheduler.yaml
```

```
admin.conf               kubelet.conf  pki           super-admin.conf
controller-manager.conf  manifests     scheduler.conf
staticPodPath: /etc/kubernetes/manifests
etcd.yaml            kube-controller-manager.yaml
kube-apiserver.yaml  kube-scheduler.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    component: kube-scheduler
    tier: control-plane
  name: kube-scheduler
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-scheduler
    - --authentication-kubeconfig=/etc/kubernetes/scheduler.conf
    - --authorization-kubeconfig=/etc/kubernetes/scheduler.conf
```

The kubelet's `staticPodPath` is the manifests folder, and each file in it is an ordinary Pod
definition (`kind: Pod`). The kubelet runs them without asking the API server first. It is how the
control plane starts before there is a control plane to ask. The pods you saw in Step 1 are
read-only copies the kubelet publishes so you can see them.

Now the map, proved from these files. Which part is set up to reach etcd, and where does each part
look for the API server?

```bash
grep -l -- --etcd-servers /etc/kubernetes/manifests/*.yaml
grep server: /etc/kubernetes/*.conf
exit
```

```
/etc/kubernetes/manifests/kube-apiserver.yaml
/etc/kubernetes/admin.conf:    server: https://unlocked-control-plane:6443
/etc/kubernetes/controller-manager.conf:    server: https://172.19.0.3:6443
/etc/kubernetes/kubelet.conf:    server: https://172.19.0.3:6443
/etc/kubernetes/scheduler.conf:    server: https://172.19.0.3:6443
/etc/kubernetes/super-admin.conf:    server: https://unlocked-control-plane:6443
```

`grep -l` prints only the names of matching files, and `--` on its own tells grep that what follows
is the pattern, not an option. Only `kube-apiserver.yaml` has `--etcd-servers`: no other part talks
to etcd. Every `.conf` file points at the API server on port 6443 (the address is the node's, on
Docker's network, and differs on your machine). Every part talks to the API server, and to nothing
else. `exit` leaves the node's shell.

---

## Step 3 (optional): the API server's health

Every kubectl command is an HTTPS request to the API server. It has health checks you can read.
`--raw` sends a plain request to a path on the API server:

```bash
kubectl get --raw='/readyz?verbose' | tail -4
```

```
[+]poststarthook/apiservice-openapi-controller ok
[+]poststarthook/apiservice-openapiv3-controller ok
[+]shutdown ok
readyz check passed
```

Drop the `| tail -4` to see all of them, including `[+]etcd ok`: the API server cannot answer
without etcd.

---

## Step 4: etcd

Create a Deployment, then read what it turned into, straight out of etcd. Read the file first:

```bash
cat manifests/web.yaml
```

The same shape as before: a Deployment called `web`, two replicas.

```bash
kubectl delete events --all
kubectl apply -f manifests/web.yaml
kubectl rollout status deployment/web
```

etcd only talks to clients that show a certificate, so `etcdctl`, etcd's own command line tool,
needs three files: the certificate authority that signed etcd's certificate (`--cacert`), and a
certificate and key to prove who we are (`--cert`, `--key`). All three already exist inside the
etcd pod. `kubectl exec` runs a command in a pod; everything after `--` is that command:

```bash
kubectl exec -n kube-system etcd-unlocked-control-plane -- etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/ --prefix --keys-only | grep web
```

```
/registry/deployments/default/web
/registry/events/default/web-5b55b57fbd-fvcvf.18dd47e2ba7bc9dd
...
/registry/events/default/web.18dd47e2ba05220d
/registry/pods/default/web-5b55b57fbd-fvcvf
/registry/pods/default/web-5b55b57fbd-xtz4w
/registry/replicasets/default/web-5b55b57fbd
```

`get /registry/ --prefix --keys-only` lists every key that starts with `/registry/`, without
values; `grep web` keeps the ones about our app. What just happened: you wrote one Deployment.
etcd now also holds a ReplicaSet, two pods and a dozen events. Something else wrote those.

---

## Step 5: who did what

Events record what happened, and which component did it. Raw `kubectl get events` is very wide,
so pick the columns: the component that wrote each event, the reason, and the kind of object.
Here the `\` sits inside the custom-columns value, so the next line has no indent:

```bash
kubectl get events --sort-by=.metadata.creationTimestamp -o custom-columns=\
FROM:.reportingComponent,REASON:.reason,KIND:.involvedObject.kind
```

```
FROM                    REASON              KIND
default-scheduler       Scheduled           Pod
default-scheduler       Scheduled           Pod
replicaset-controller   SuccessfulCreate    ReplicaSet
replicaset-controller   SuccessfulCreate    ReplicaSet
deployment-controller   ScalingReplicaSet   Deployment
kubelet                 Pulled              Pod
kubelet                 Created             Pod
kubelet                 Started             Pod
...
```

Events are timestamped to the second, so rows written in the same second are not in exact order.
The real order:

1. **You** send the Deployment to the **API server**, which stores it in **etcd**.
2. The **deployment controller** (in the controller manager) sees it and creates a ReplicaSet.
3. The **replicaset controller** creates two Pods. They have no node yet.
4. The **scheduler** picks a node for each Pod and writes it down.
5. The **kubelet** on that node sees a Pod assigned to it and tells **containerd** to start it.

None of them talk to each other. Each one watches the API server for its kind of work.

---

## Step 6: a worker node

`--field-selector` filters on a field of the object, here the node a pod runs on, and `-A`
looks in every namespace:

```bash
kubectl get pods -A --field-selector spec.nodeName=unlocked-worker
docker exec unlocked-worker systemctl is-active kubelet containerd
```

```
NAMESPACE     NAME                   READY   STATUS    RESTARTS   AGE
default       web-5b55b57fbd-xtz4w   1/1     Running   0          14s
kube-system   kindnet-99q55          1/1     Running   0          130m
kube-system   kube-proxy-tt99z       1/1     Running   0          130m
active
active
```

What just happened: the worker runs the network plugin, kube-proxy, and your web pods. The
kubelet and containerd are not pods: `systemctl` (the node's service manager) reports them as
running services, because something has to be running before any pod can start.

To see the same thing from the container runtime's side, run `crictl ps` on the node
(`docker exec unlocked-worker crictl ps`). Its table is wide, but it lists the same containers.

---

## Who runs this in production?

kind is for learning and CI: all three "machines" are containers on one computer. Real clusters
split the work differently:

| | kind (this series) | Managed: EKS, GKE, AKS | Self-managed: kubeadm on VMs or servers |
|---|---|---|---|
| Control plane | containers on your machine | the provider. You never see etcd or API server pods. | you |
| Worker nodes | containers on your machine | you, or the provider in fully managed modes | you |
| Used for | learning, CI | most production clusters | full control, or no cloud |

If you run the control plane yourself, you also own:

- **High availability:** at least three control plane nodes (each with an etcd member), with the
  API servers behind a load balancer.
- **etcd backups**, and practising the restore.
- **Certificates:** kubeadm's client certificates expire after one year.
- **Upgrades:** one minor version at a time. Each minor version gets patches for about 14 months.
- **The machines:** OS patches, disk, and monitoring of the control plane itself.

Managed Kubernetes and backups each get their own episode later in the series.

---

## Check your work

```bash
./verify.sh
```

```
Episode 3: Kubernetes Architecture

  PASS  kubectl is pointed at the series cluster (kind-unlocked)
  PASS  all four control plane manifests are in place
  PASS  kube-apiserver is Running on the control plane
  PASS  etcd is Running on the control plane
  PASS  kube-scheduler is Running on the control plane
  PASS  kube-controller-manager is Running on the control plane
  PASS  kube-proxy runs on all 3 nodes
  PASS  kindnet (the network plugin) runs on all 3 nodes
  PASS  the API server reports ready (/readyz)
  PASS  the web Deployment is stored in etcd
  PASS  every web pod it asks for is actually Running (counted, not read from its status)
  PASS  every web pod was given a node by the scheduler

All 12 checks passed.
```

---

## Break it on purpose

A control plane part stops when its file leaves `/etc/kubernetes/manifests`, and starts again
when the file comes back. `docker exec` runs `mv` on the node without opening a shell. If you get
lost, `./verify.sh` prints the exact command that puts each file back.

This command shows where every web pod is. You will run it several times:

```bash
kubectl get pods -l app=web -o custom-columns=\
POD:.metadata.name,PHASE:.status.phase,NODE:.spec.nodeName
```

### Without a scheduler

```bash
docker exec unlocked-control-plane \
  mv /etc/kubernetes/manifests/kube-scheduler.yaml /etc/kubernetes/
kubectl get pods -n kube-system -l component=kube-scheduler
kubectl scale deployment web --replicas=4
kubectl get pods -l app=web -o custom-columns=\
POD:.metadata.name,PHASE:.status.phase,NODE:.spec.nodeName
```

Give the kubelet a few seconds after the `mv` before you check:

```
No resources found in kube-system namespace.
deployment.apps/web scaled
POD                    PHASE     NODE
web-5b55b57fbd-9dcqb   Pending   <none>
web-5b55b57fbd-fvcvf   Running   unlocked-worker2
web-5b55b57fbd-skjx5   Pending   <none>
web-5b55b57fbd-xtz4w   Running   unlocked-worker
```

`-l component=kube-scheduler` selects pods by a label (the manifest you read in Step 2 sets it).
The scheduler is gone. The API server accepted the change and the controller manager created two
new pods, but they stay `Pending` with no node, for as long as you wait. No event explains why:
events are written by the component doing the work, and the one that places pods is not running.
Put the file back:

```bash
docker exec unlocked-control-plane \
  mv /etc/kubernetes/kube-scheduler.yaml /etc/kubernetes/manifests/
kubectl rollout status deployment/web
kubectl get pods -l app=web -o custom-columns=\
POD:.metadata.name,PHASE:.status.phase,NODE:.spec.nodeName
```

```
deployment "web" successfully rolled out
POD                    PHASE     NODE
web-5b55b57fbd-9dcqb   Running   unlocked-worker2
web-5b55b57fbd-fvcvf   Running   unlocked-worker2
web-5b55b57fbd-skjx5   Running   unlocked-worker
web-5b55b57fbd-xtz4w   Running   unlocked-worker
```

### Without a controller manager

```bash
docker exec unlocked-control-plane \
  mv /etc/kubernetes/manifests/kube-controller-manager.yaml /etc/kubernetes/
kubectl delete pods -l app=web
kubectl get pods -l app=web -o custom-columns=\
POD:.metadata.name,PHASE:.status.phase,NODE:.spec.nodeName
kubectl get deployment web
```

```
pod "web-5b55b57fbd-9dcqb" deleted from default namespace
pod "web-5b55b57fbd-fvcvf" deleted from default namespace
pod "web-5b55b57fbd-skjx5" deleted from default namespace
pod "web-5b55b57fbd-xtz4w" deleted from default namespace
POD   PHASE   NODE
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
web    4/4     4            4           41s
```

Every pod is gone and nothing replaces them: the table has headers and no rows. In Episode 1 a
deleted pod came straight back; that was the controller manager. And the Deployment still says
`4/4` ready. Its status is written by the controller manager too, so with it gone, nobody
corrects it. Status is a report, not a measurement. Put the file back:

```bash
docker exec unlocked-control-plane \
  mv /etc/kubernetes/kube-controller-manager.yaml /etc/kubernetes/manifests/
```

Wait about 30 seconds (it waits for a lock that only one controller manager may hold), then run
the custom-columns command again: four new pods. Then:

```bash
./verify.sh
```

---

## Try this yourself

Delete the scheduler's pod with kubectl:

```bash
kubectl delete pod -n kube-system kube-scheduler-unlocked-control-plane
```

Then run `kubectl get pods -n kube-system` a few times. Is the scheduler gone? Did it restart? Look
at its container on the node with `docker exec unlocked-control-plane crictl ps --name
kube-scheduler`. Explain what you see. Answer in [solutions/](solutions/).

## Quiz

1. Which component is the only one that talks to etcd?
2. A new pod is `Pending` and its node is `<none>`. Which component do you suspect first?
3. You delete a pod owned by a Deployment and it does not come back. Which component is missing?
4. Why do the kubelet and containerd not run as pods?
5. Who starts the API server, if not a Deployment?

<details>
<summary>Answers</summary>

1. The API server. Every other component reads and writes through it.
2. The scheduler. Placing pods on nodes is its only job.
3. The controller manager. Its controllers create the replacement.
4. They are what starts pods. Something has to be running on the node before any pod can.
5. The kubelet on the control-plane node, from the files in `/etc/kubernetes/manifests`
   (static pods).

</details>

## Clean up

```bash
kubectl delete -f manifests/ --ignore-not-found
```

If `./verify.sh` says a control plane file is missing, run the command it prints. Leave the
cluster running for the next episode.

## Commands in this episode

| Command | What it does |
|---------|--------------|
| `cat <file>` | Print a file, to read a manifest before you apply it |
| `kubectl get pods -n kube-system` | List pods in one namespace (`-n`) |
| `kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName` | Print only the columns you name, as `HEADER:path` |
| `docker exec -it unlocked-control-plane bash` | Open a shell on a kind node |
| `ls /etc/kubernetes/manifests` | On the control-plane node: the static pod files |
| `grep staticPodPath /var/lib/kubelet/config.yaml` | Print the lines of a file that match a pattern |
| `grep -l -- --etcd-servers <files>` | Print only the names of files that match (`--` ends the options) |
| `kubectl get --raw='/readyz?verbose'` | Ask the API server for its health checks |
| `kubectl exec -n kube-system <pod> -- <command>` | Run a command inside a pod |
| `etcdctl --cacert ... --cert ... --key ... get /registry/ --prefix --keys-only` | List the keys etcd stores |
| `kubectl get events --sort-by=.metadata.creationTimestamp` | List events, oldest first |
| `kubectl get pods -A --field-selector spec.nodeName=<node>` | Pods on one node, in every namespace |
| `docker exec <node> systemctl is-active kubelet containerd` | Check the node's services |
| `kubectl get pods -l component=kube-scheduler` | Select pods by label |
| `docker exec <node> mv <file> <folder>` | Run one command on a node without a shell |
| `kubectl scale deployment web --replicas=4` | Change the number of copies |
| `kubectl delete pods -l app=web` | Delete every pod with a label |
| `kubectl delete pod -n kube-system <name>` | Delete one pod in another namespace |

## Going deeper


- [Kubernetes components](https://kubernetes.io/docs/concepts/overview/components/)
- [Static pods](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/)
- [Operating etcd clusters](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)
- CKA domain: Cluster Architecture, Installation and Configuration
