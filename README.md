# Kubernetes Unlocked

Hands-on Kubernetes labs, from zero to production-ready. Every episode is a lab you can finish
without watching the video, and every lab ships a `verify.sh` that tells you whether you got it
right.

Validated on **Kubernetes 1.37** (Kind v0.33.0).

Videos: [Kubernetes Unlocked playlist](https://www.youtube.com/playlist?list=PLKi-TqorBrPI) on the
[Labs Unlocked](https://www.youtube.com/@sklabsunlocked) channel.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (Docker Desktop on macOS and Windows)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) v0.33.0 or later
- [kubectl](https://kubernetes.io/docs/tasks/tools/) 1.36, 1.37 or 1.38
- macOS, Linux, or Windows with WSL2. About 4 GB of free memory.

## Set up the cluster

```bash
./cluster/up.sh
```

```
NAME                     STATUS   ROLES           AGE   VERSION
unlocked-control-plane   Ready    control-plane   29s   v1.37.0
unlocked-worker          Ready    <none>          16s   v1.37.0
unlocked-worker2         Ready    <none>          16s   v1.37.0
```

One control plane and two workers, all running in Docker. `./cluster/down.sh` deletes it.

## Episodes

The course runs in five phases. Each phase ends with a checkpoint episode that builds something
from everything in it. Labs appear here as their videos are published.

### Phase 1: Foundations

What Kubernetes is, a cluster of your own, and every basic workload.

| # | Episode | Lab | Video |
|---|---------|-----|-------|
| 1 | What Is Kubernetes? | [01-what-is-kubernetes](episodes/01-what-is-kubernetes/) | [Watch](https://youtu.be/LxoE2HtTURI) |
| 2 | Set Up a Local Kubernetes Cluster | [02-local-cluster](episodes/02-local-cluster/) | [Watch](https://youtu.be/3f9-QAc4pd4) |
| 3 | Kubernetes Architecture | [03-architecture](episodes/03-architecture/) | [Watch](https://youtu.be/YrInSrkAsq4) |
| 4 | Pods in Depth | [04-pods](episodes/04-pods/) | [Watch](https://youtu.be/akieVSdAnAc) |

### Phase 2: Networking and configuration

Services, DNS, Ingress and Gateway API, HTTPS with cert-manager, ConfigMaps and Secrets, probes and
graceful shutdown.

### Phase 3: Storage and scaling

Volumes, StatefulSets, requests and limits, autoscaling, rollout strategies, Kustomize and Helm.

### Phase 4: Security and operations

Authentication and RBAC, network policies and Pod Security, logging and monitoring,
troubleshooting, scheduling.

### Phase 5: Production

GitOps, CRDs and operators, building a cluster with kubeadm, managed Kubernetes, backup and
disaster recovery, cost, security hardening, and a capstone that takes one app from an empty
cluster to production-ready.

### Phase 6: Advanced

After the capstone, chosen by what learners ask for. Candidates: service meshes, multi-cluster,
building an operator in Go, and serverless with Knative.

Not covered: Windows nodes. kind cannot run them, so there would be no hands-on lab.

## How every lab works

1. `cd episodes/NN-name` and follow its README. Expected output is shown after every command.
2. Run `./verify.sh`. Green means you got there. Red comes with a hint.
3. Try the exercise. Answers are in `solutions/`.
4. Clean up with the command at the end of the README.

Stuck? See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## License

Code is MIT ([LICENSE](LICENSE)). Written material and diagrams are CC BY 4.0
([LICENSE-docs](LICENSE-docs)). If you teach from this, attribution and a link back is all I ask.

Made by Sanjeev Kumar.
