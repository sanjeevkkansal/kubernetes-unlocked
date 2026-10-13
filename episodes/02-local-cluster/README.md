# Episode 2: Set Up a Local Kubernetes Cluster

Video: coming soon  |  Lab time: about 20 minutes (plus an optional 5-minute wait)

Phase 1: Foundations  |  Previous: [Episode 1](../01-what-is-kubernetes/)  |  Next: [Episode 3](../03-architecture/)

## What you will be able to do

- Install Docker, kind and kubectl, and check their versions match the series.
- Create a cluster from a config file, delete it, and rebuild it in one command.
- Show that each node is a Docker container, and that kubectl reaches it through a context.
- Run a Deployment and see its pods spread across two workers.
- Stop a worker and watch what Kubernetes does, and when.

## Before you start

Install the three tools in the [repo README prerequisites](../../README.md#prerequisites):
Docker, kind and kubectl. On Windows, use WSL2 and run everything inside it.

Run every command from this folder:

```bash
cd episodes/02-local-cluster
```

Names with random suffixes (`hello-78f4f86854-...`), ages, IP addresses and port numbers will
differ on your machine. Everything else should match.

---

## Step 1: check your tools

```bash
docker version --format '{{.Server.Version}}'
kind version
kubectl version --client
```

```
29.3.1
kind v0.33.0 go1.26.7 darwin/arm64
Client Version: v1.37.1
Kustomize Version: v5.8.1
```

Your version numbers can be newer. `--format` asks Docker for one field, the server version, so
if Docker is installed but not running you get an error here instead of a number.
`--client` asks kubectl about itself only; there is no cluster to talk to yet.

What just happened: kind runs Kubernetes nodes as Docker containers, so Docker must be running.
kubectl is the client you use to talk to any cluster.

---

## Step 2: the smallest cluster

```bash
kind create cluster --config kind/single-node.yaml
```

```
Creating cluster "first" ...
 ✓ Ensuring node image (kindest/node:v1.37.0) 🖼️
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-first"
...
```

The first run downloads the node image, about 1.3 GB, so it can take a few minutes. After that,
a cluster takes around 10 seconds.

```bash
kubectl wait --for=condition=Ready nodes --all --timeout=120s
kubectl get nodes
```

```
node/first-control-plane condition met
NAME                  STATUS   ROLES           AGE   VERSION
first-control-plane   Ready    control-plane   22s   v1.37.0
```

`kubectl wait` blocks until a condition is true: here `Ready`, for `--all` nodes, giving up after
`--timeout`. Run `kubectl get nodes` straight after creating and you may see `NotReady` for a few
seconds while the node's network plugin (the CNI from the list above) starts.

One node doing everything works, but it cannot show you what happens when a machine fails.
Delete it:

```bash
kind delete cluster --name first
```

```
Deleting cluster "first" ...
Deleted nodes: ["first-control-plane"]
```

What just happened: [kind/single-node.yaml](kind/single-node.yaml) named the cluster and pinned
the node image, so you got Kubernetes v1.37.0 and not whatever kind defaults to this month.

---

## Step 3: the series cluster

Every lab from here on uses one cluster. Read its config, then the script that builds it. Read
any script before you run it:

```bash
cat ../../cluster/kind-config.yaml
cat ../../cluster/up.sh
```

The config asks for one `control-plane` node and two `worker` nodes, all from the same pinned
image. The script:

```
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
```

It checks the three tools, runs the same `kind create cluster` you just ran (only if the cluster
is missing), points kubectl at it, and waits for every node. Run it:

```bash
../../cluster/up.sh
```

```
Creating cluster "unlocked" ...
...
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-unlocked"
...
node/unlocked-control-plane condition met
node/unlocked-worker condition met
node/unlocked-worker2 condition met
NAME                     STATUS   ROLES           AGE   VERSION
unlocked-control-plane   Ready    control-plane   27s   v1.37.0
unlocked-worker          Ready    <none>          12s   v1.37.0
unlocked-worker2         Ready    <none>          12s   v1.37.0
```

From an empty Docker, with the image already downloaded, this took 33 seconds. If the cluster
already exists, `up.sh` says so and only points kubectl back at it.

---

## Step 4: it is just containers

```bash
docker ps --filter name=unlocked \
  --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
```

```
NAMES                    IMAGE                  PORTS
unlocked-worker2         kindest/node:v1.37.0
unlocked-worker          kindest/node:v1.37.0
unlocked-control-plane   kindest/node:v1.37.0   127.0.0.1:65378->6443/tcp
```

`--filter name=unlocked` keeps only the cluster's containers (you may have others), and
`--format` picks three columns. Each node is a container. Only the control plane publishes a
port: 6443 is the Kubernetes API. kubectl finds it through the current context:

```bash
kubectl config current-context
kubectl cluster-info
```

```
kind-unlocked
Kubernetes control plane is running at https://127.0.0.1:65378
CoreDNS is running at https://127.0.0.1:65378/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

What just happened: kind wrote the address and credentials into `~/.kube/config` under a context
named `kind-unlocked`. By default, every kubectl command goes to the current context; add
`--context <name>` to send one command somewhere else. A context also sets your default namespace
(more on that in the episode on namespaces). If you also use other clusters, check the current
context before you run anything. Your port number will differ.

---

## Step 5: run something

Read the file first:

```bash
cat manifests/hello-deployment.yaml
```

The same shape as Episode 1's Deployment: this one is called `hello`, with four replicas.

```bash
kubectl apply -f manifests/hello-deployment.yaml
kubectl rollout status deployment/hello
```

```
deployment.apps/hello created
Waiting for deployment "hello" rollout to finish: 0 of 4 updated replicas are available...
...
deployment "hello" successfully rolled out
```

Where did the four pods land? `kubectl get pods -o wide` shows the node, along with the pod IP
and three more columns, in a table too wide for most screens. `-o custom-columns` prints only the
columns you name, each as `HEADER:path`, where the path points into the pod's details. The `\`
at the end of the first line continues the command; it sits inside the column list, so the second
line has no indent:

```bash
kubectl get pods -l app=hello -o custom-columns=\
POD:.metadata.name,PHASE:.status.phase,NODE:.spec.nodeName
```

```
POD                      PHASE     NODE
hello-78f4f86854-fj6wc   Running   unlocked-worker
hello-78f4f86854-tdm5b   Running   unlocked-worker
hello-78f4f86854-txcwg   Running   unlocked-worker2
hello-78f4f86854-tz87c   Running   unlocked-worker2
```

What just happened: the scheduler spread the four pods across the two workers. None went to the
control plane. Its node is marked (tainted) so ordinary pods are not scheduled there, and it is
left to run the cluster's own components.

---

## Check your work

```bash
./verify.sh
```

```
Episode 2: Set Up a Local Cluster

  PASS  docker, kind and kubectl are installed and Docker is running
  PASS  a kind cluster named 'unlocked' exists
  PASS  kubectl is pointed at it (context kind-unlocked)
  PASS  it has 3 nodes
  PASS  1 control plane and 2 workers
  PASS  all nodes are Ready
  PASS  every node runs Kubernetes v1.37
  PASS  the system pods in kube-system are Running
  PASS  the hello Deployment has 4 ready replicas
  PASS  its pods run on more than one node

All 10 checks passed.
```

A `FAIL` line comes with a hint telling you the exact command to run.

---

## Break it on purpose

A worker is a container, so you can switch one off:

```bash
docker stop unlocked-worker2
kubectl get nodes
```

For the first 50 seconds or so, nothing changes. Kubernetes has not missed enough heartbeats
yet. Run `kubectl get nodes` again until you see:

```
NAME                     STATUS     ROLES           AGE   VERSION
unlocked-control-plane   Ready      control-plane   87s   v1.37.0
unlocked-worker          Ready      <none>          72s   v1.37.0
unlocked-worker2         NotReady   <none>          72s   v1.37.0
```

Now look at the pods:

```bash
kubectl get pods -l app=hello -o custom-columns=\
POD:.metadata.name,PHASE:.status.phase,NODE:.spec.nodeName
```

```
POD                      PHASE     NODE
hello-78f4f86854-fj6wc   Running   unlocked-worker
hello-78f4f86854-tdm5b   Running   unlocked-worker
hello-78f4f86854-txcwg   Running   unlocked-worker2
hello-78f4f86854-tz87c   Running   unlocked-worker2
```

The two pods on `unlocked-worker2` are still listed as `Running`. The control plane cannot reach
that node, so it cannot know what is really happening there. It does not replace them yet: by
default every pod tolerates an unreachable node for 300 seconds, in case it is a short network
blip.

**Optional: wait 5 minutes**, then look again, first with the plain list:

```bash
kubectl get pods -l app=hello
```

```
NAME                     READY   STATUS        RESTARTS   AGE
hello-78f4f86854-7gvxv   1/1     Terminating   0          7m7s
hello-78f4f86854-jf9bw   1/1     Running       0          7m7s
hello-78f4f86854-mvk6q   1/1     Running       0          21s
hello-78f4f86854-pm2pw   1/1     Running       0          21s
hello-78f4f86854-vnfls   1/1     Running       0          7m7s
hello-78f4f86854-z6jrp   1/1     Terminating   0          7m7s
```

Two replacements are running, so you have 4 again. The old two show `Terminating`. Add a column
for the time each pod was marked for deletion:

```bash
kubectl get pods -l app=hello -o custom-columns=\
POD:.metadata.name,PHASE:.status.phase,NODE:.spec.nodeName,\
DELETING:.metadata.deletionTimestamp
```

```
POD                      PHASE     NODE               DELETING
hello-78f4f86854-7gvxv   Running   unlocked-worker2   2026-10-12T17:50:12Z
hello-78f4f86854-jf9bw   Running   unlocked-worker    <none>
hello-78f4f86854-mvk6q   Running   unlocked-worker    <none>
hello-78f4f86854-pm2pw   Running   unlocked-worker    <none>
hello-78f4f86854-vnfls   Running   unlocked-worker    <none>
hello-78f4f86854-z6jrp   Running   unlocked-worker2   2026-10-12T17:50:12Z
```

The two pods on `unlocked-worker2` still have PHASE `Running`, but they have a deletion time.
`Terminating` is not a phase: it is how `kubectl get pods` shows a pod that has been marked for
deletion. The phase cannot change, because only the kubelet on that node reports it, and that
node is down. The new pods went to the healthy worker.

Bring the worker back:

```bash
docker start unlocked-worker2
kubectl wait --for=condition=Ready nodes --all --timeout=180s
```

The node is Ready again within seconds. Give it a few more seconds and the `Terminating` pods
disappear:

```bash
kubectl get pods -l app=hello -o custom-columns=\
POD:.metadata.name,PHASE:.status.phase,NODE:.spec.nodeName
```

```
POD                      PHASE     NODE
hello-78f4f86854-4g247   Running   unlocked-worker
hello-78f4f86854-fj6wc   Running   unlocked-worker
hello-78f4f86854-rfxmp   Running   unlocked-worker
hello-78f4f86854-tdm5b   Running   unlocked-worker
```

All four pods are now on `unlocked-worker`. Kubernetes does not move running pods back on its
own, and `./verify.sh` fails its last check. `kubectl rollout restart` replaces the pods a few at
a time, and the scheduler places each new one:

```bash
kubectl rollout restart deployment/hello
kubectl rollout status deployment/hello
kubectl get pods -l app=hello -o custom-columns=\
POD:.metadata.name,PHASE:.status.phase,NODE:.spec.nodeName
./verify.sh
```

```
POD                      PHASE     NODE
hello-86dd48ddf9-7n5wk   Running   unlocked-worker
hello-86dd48ddf9-k285d   Running   unlocked-worker2
hello-86dd48ddf9-w4qwr   Running   unlocked-worker2
hello-86dd48ddf9-wdv5v   Running   unlocked-worker
```

If you look within a second or two of the restart, the old pods may still be listed with PHASE
`Succeeded` (they stopped cleanly); they disappear on their own.

---

## Try this yourself

Create a second cluster named `big` with one control plane and **three** workers, using the same
pinned image. Check all four nodes are Ready, then delete it and switch back with `up.sh`.
Answer in [solutions/](solutions/).

## Quiz

1. What is a kind node, physically?
2. You create a second kind cluster. Which cluster does your next `kubectl` command go to?
3. A worker stops. Why are its pods still shown as `Running` a minute later?
4. Why did the replacement pods take about 5 minutes to appear?
5. Why pin the node image by digest and not just `kindest/node:v1.37.0`?

<details>
<summary>Answers</summary>

1. A Docker container running the kubelet and a container runtime.
2. The new one. `kind create cluster` sets the current context to it.
3. The control plane cannot reach the node, so the last status it heard stands. It marks the node
   `NotReady` first and only acts on the pods later.
4. By default each pod tolerates a not-ready or unreachable node for 300 seconds before it is
   evicted. The Deployment then replaces it.
5. A tag can be moved to different contents. A digest identifies exactly one image, so every
   learner and the CI get the same node.

</details>

## Clean up

```bash
kubectl delete -f manifests/ --ignore-not-found
```

Leave the cluster running for the next episode, where we open it up and find the parts that make
Kubernetes work. To remove it: `../../cluster/down.sh`.

## Commands in this episode

| Command | What it does |
|---------|--------------|
| `cat <file>` | Print a file, to read it before you run or apply it |
| `docker version --format '{{.Server.Version}}'` | Docker's server version; an error means Docker is not running |
| `kind version` | kind's version |
| `kubectl version --client` | kubectl's own version, without asking a cluster |
| `kind create cluster --config <file>` | Create a cluster from a config file |
| `kubectl wait --for=condition=Ready nodes --all --timeout=120s` | Block until every node is Ready |
| `kubectl get nodes` | List the cluster's nodes |
| `kind delete cluster --name <name>` | Delete a cluster and its containers |
| `kind get clusters` | List the kind clusters that exist |
| `../../cluster/up.sh` | Create the series cluster, or point kubectl back at it |
| `../../cluster/down.sh` | Delete the series cluster |
| `docker ps --filter name=unlocked` | List only the cluster's node containers |
| `kubectl config current-context` | Which cluster kubectl is talking to |
| `kubectl cluster-info` | The API server address for the current context |
| `kubectl rollout status deployment/<name>` | Wait until a Deployment's pods are ready |
| `kubectl get pods -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName` | Only the columns you name |
| `docker stop <node>` | Switch a node off (it is a container) |
| `docker start <node>` | Switch it back on |
| `kubectl rollout restart deployment/<name>` | Replace a Deployment's pods, a few at a time |

The three nodes use about 1.1 GB of memory when idle. A cluster that seems broken after a laptop
restart usually just has Docker not running.

## Going deeper

- [kind quick start](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [kind configuration](https://kind.sigs.k8s.io/docs/user/configuration/)
- [Install kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Taint-based evictions](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/#taint-based-evictions)
- CKA domain: Cluster Architecture, Installation and Configuration
