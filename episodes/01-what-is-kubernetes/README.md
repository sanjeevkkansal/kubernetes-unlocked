# Episode 1: What Is Kubernetes?

Video: coming soon  |  Lab time: about 20 minutes

Phase 1: Foundations  |  Next: [Episode 2](../02-local-cluster/)

## What you will be able to do

- Say what plain Docker does for you, and where it stops.
- Explain desired state: you declare what you want, Kubernetes keeps making it true.
- Tell a Pod from a Deployment, and watch a Deployment replace a pod you delete.

## Before you start

- **Part 1** needs Docker only.
- **Part 2** needs the local cluster. From the repo root run `./cluster/up.sh`
  ([setup](../../README.md#set-up-the-cluster)). Episode 2 explains it in detail.

Run every command from this folder:

```bash
cd episodes/01-what-is-kubernetes
```

Pod names (`nginx-deployment-84d6fbc79d-...`) and ages will differ on your machine. Everything
else should match.

---

## Part 1: containers the hard way

Plain Docker first, because you probably use it already. The commands use the image tag
`nginx:1.30.5-alpine` to stay readable; the Kubernetes manifests in Part 2 pin the same image by
digest.

### Step 1: run one web server

```bash
docker run -d --name web1 -p 8080:80 nginx:1.30.5-alpine
docker ps -a --filter name=web \
  --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

```
ff3704a81fbca1be55e89df23ece7d65377ba15a1727188ab2e548c14b295791
NAMES     STATUS        PORTS
web1      Up 1 second   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp
```

`docker run -d` starts a container in the background and prints its ID. `-p 8080:80` sends port
8080 on your machine to port 80 in the container. `docker ps -a` lists containers, including
stopped ones; `--filter name=web` keeps only ours, and `--format` picks three columns.

### Step 2: the server process dies

```bash
docker exec web1 kill 1
docker ps -a --filter name=web \
  --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

```
NAMES     STATUS                     PORTS
web1      Exited (0) 2 seconds ago
```

`docker exec` runs a command inside a running container. `kill 1` stops process 1, the web
server. The container is now `Exited`, and nothing starts it again. You find out when a user
tells you.

### Step 3: Docker's answer, a restart policy

```bash
docker rm -f web1
docker run -d --name web1 -p 8080:80 --restart always nginx:1.30.5-alpine
docker exec web1 kill 1
docker inspect -f '{{.RestartCount}} {{.State.Status}}' web1
```

```
web1
0c0ebe960ca261a8071e00fd301a80407a22405c9e416c8f796aa5d955c369bc
1 running
```

`--restart always` tells Docker to start the container again when it stops. `docker inspect`
reads one container's details; `-f` picks fields from them. It restarted once and is running.
But Docker restarts it on this machine only. If the machine dies, so does `web1`.

### Step 4: traffic triples

```bash
docker run -d --name web2 -p 8081:80 --restart always nginx:1.30.5-alpine
docker run -d --name web3 -p 8082:80 --restart always nginx:1.30.5-alpine
docker ps -a --filter name=web \
  --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

```
NAMES     STATUS         PORTS
web3      Up 4 seconds   0.0.0.0:8082->80/tcp, [::]:8082->80/tcp
web2      Up 4 seconds   0.0.0.0:8081->80/tcp, [::]:8081->80/tcp
web1      Up 4 seconds   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp
```

Three copies, three ports, and nothing in front to share traffic between them. Updating them
means stopping and recreating each one by hand. Clean up:

```bash
docker rm -f web1 web2 web3
```

What just happened:

```
    What Docker gave you          What is still on you
    restart on this machine       moving work when a machine dies
    run another copy              one address in front of all copies
                                  updating copies without downtime
                                  keeping the count you asked for
```

Everything in the right column is the work Kubernetes takes over.

---

## Part 2: the Kubernetes way

### Step 1: run a single Pod

Read the file first:

```bash
cat manifests/nginx-pod.yaml
```

Kind `Pod`, a name, and one container: nginx, from an image pinned to an exact version, on port
80. That is the whole object. Apply it:

```bash
kubectl apply -f manifests/nginx-pod.yaml
kubectl get pods
```

Expected output:

```
pod/nginx-pod created
NAME        READY   STATUS    RESTARTS   AGE
nginx-pod   1/1     Running   0          5s
```

A Pod is one or more containers that run together. Now delete it:

```bash
kubectl delete pod nginx-pod
kubectl get pods
```

```
pod "nginx-pod" deleted from default namespace
No resources found in default namespace.
```

What just happened: nothing was watching that Pod, so it stayed gone. That is the same problem as
plain Docker.

### Step 2: declare three copies with a Deployment

Read the file first:

```bash
cat manifests/nginx-deployment.yaml
```

The same nginx container, now inside a `template`, and one new line: `replicas: 3`. The
`selector` says which pods belong to the Deployment: the ones labelled `app: nginx`.

```bash
kubectl apply -f manifests/nginx-deployment.yaml
kubectl get deployments
kubectl get pods -l app=nginx -o wide
```

```
deployment.apps/nginx-deployment created
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   3/3     3            3           4s
NAME                                READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
nginx-deployment-84d6fbc79d-jz47j   1/1     Running   0          4s    10.244.1.4   unlocked-worker    <none>           <none>
nginx-deployment-84d6fbc79d-l5k5m   1/1     Running   0          4s    10.244.2.2   unlocked-worker2   <none>           <none>
nginx-deployment-84d6fbc79d-tdqgd   1/1     Running   0          4s    10.244.1.3   unlocked-worker    <none>           <none>
```

If `READY` shows `0/3` or `1/3`, wait a few seconds and run it again. The image is still
downloading.

What just happened: the file says `replicas: 3`. Kubernetes created three pods and spread them
across the two worker nodes.

### Step 3: delete a pod and watch it come back

Copy one pod name from your own output:

```bash
kubectl delete pod <one-of-your-pod-names>
kubectl get pods -l app=nginx
```

```
pod "nginx-deployment-84d6fbc79d-jz47j" deleted from default namespace
NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-84d6fbc79d-9j29m   1/1     Running   0          1s
nginx-deployment-84d6fbc79d-l5k5m   1/1     Running   0          15s
nginx-deployment-84d6fbc79d-tdqgd   1/1     Running   0          15s
```

What just happened: you asked for three, there were two, so Kubernetes made a new one. Look at
the `AGE` column. That 1-second-old pod is the replacement. This is called reconciliation, and
it never stops running.

To watch it live, run `kubectl get pods -l app=nginx -w` in a second terminal, delete a pod in
the first, and press Ctrl+C when you are done.

### Step 4: scale with one command

```bash
kubectl scale deployment nginx-deployment --replicas=5
kubectl get pods -l app=nginx
```

```
deployment.apps/nginx-deployment scaled
NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-84d6fbc79d-4q6d6   1/1     Running   0          1s
nginx-deployment-84d6fbc79d-9j29m   1/1     Running   0          5s
nginx-deployment-84d6fbc79d-l5k5m   1/1     Running   0          19s
nginx-deployment-84d6fbc79d-q4t6g   1/1     Running   0          1s
nginx-deployment-84d6fbc79d-tdqgd   1/1     Running   0          19s
```

Compare that with Part 1, where scaling meant typing out a new container and a new port.

---

## Check your work

```bash
./verify.sh
```

```
Episode 1: What Is Kubernetes

  PASS  a cluster is reachable
  PASS  nginx-deployment exists
  PASS  it asks for at least 3 replicas
  PASS  every replica it asks for is ready
  PASS  the pods with app=nginx are exactly the Deployment's pods
  PASS  nginx answers inside the pods
  PASS  the image is the pinned one from the manifest

All 7 checks passed.
```

A `FAIL` line comes with a hint telling you what to look at.

---

## Break it on purpose

Point the Deployment at an image tag that does not exist. Note the extra `e`:

```bash
kubectl apply -f manifests/nginx-deployment.yaml
kubectl set image deployment/nginx-deployment nginx=nginx:1.30.5-alpinee
kubectl get pods -l app=nginx
```

```
deployment.apps/nginx-deployment image updated
NAME                                READY   STATUS         RESTARTS   AGE
nginx-deployment-5b4487bf9f-xqjg6   0/1     ErrImagePull   0          13s
nginx-deployment-84d6fbc79d-gwwxw   1/1     Running        0          13s
nginx-deployment-84d6fbc79d-sm694   1/1     Running        0          13s
nginx-deployment-84d6fbc79d-v9cmn   1/1     Running        0          13s
```

After a minute, `ErrImagePull` turns into `ImagePullBackOff` (Kubernetes waiting longer between
retries). Read the reason:

```bash
kubectl get events --field-selector reason=Failed
```

The message says `failed to resolve reference "docker.io/library/nginx:1.30.5-alpinee"`, which
means no image has that tag.

Two things to notice:

1. The three old pods are still `Running`. Kubernetes started one new pod, saw it fail, and did
   not take the working ones away. Your site stays up during a bad update.
2. `./verify.sh` now fails, and says which checks.

Fix it by applying the file again. The file is your desired state:

```bash
kubectl apply -f manifests/nginx-deployment.yaml
./verify.sh
```

---

## Try this yourself

Get the Deployment to 4 replicas **without** `kubectl scale`. Change only the YAML, then make
`./verify.sh` pass. Answer in [solutions/](solutions/).

## Quiz

1. You delete a Pod you created from `nginx-pod.yaml`. What brings it back?
2. You delete a pod owned by a Deployment. What brings it back, and how does it know to?
3. What does a restart policy in Docker not protect you from?
4. During the broken update, why were three pods still serving?
5. Which is the source of truth: `kubectl scale`, or the YAML file?

<details>
<summary>Answers</summary>

1. Nothing. A bare Pod has no controller watching it.
2. The Deployment's ReplicaSet. It compares the pods that exist with `replicas` and creates the
   difference.
3. The machine itself failing. Docker restarts containers on the machine it runs on.
4. A rolling update replaces pods gradually and only removes old pods once new ones are ready.
5. The file, if you treat it that way. `kubectl scale` changes the live object, and the next
   `kubectl apply` puts the file's number back.

</details>

## Clean up

```bash
kubectl delete -f manifests/ --ignore-not-found
```

Leave the cluster running for the next episode. To remove it: `./cluster/down.sh` from the repo
root.

## Commands in this episode

| Command | What it does |
|---------|--------------|
| `cat <file>` | Print a file, to read a manifest before you apply it |
| `docker run -d --name web1 -p 8080:80 <image>` | Start a container in the background, port 8080 on your machine to 80 inside |
| `docker ps -a --filter name=web` | List containers, stopped ones too, only those whose name contains `web` |
| `docker exec web1 <command>` | Run a command inside a running container |
| `docker inspect -f '{{.RestartCount}}' web1` | Read one field of a container's details |
| `docker rm -f web1` | Stop and remove a container |
| `kubectl apply -f <file>` | Create or update the objects described in a file |
| `kubectl get pods` | List pods in the current namespace |
| `kubectl get pods -l app=nginx` | List only pods with the label `app=nginx` |
| `kubectl get pods -o wide` | Add the pod IP and node columns |
| `kubectl get deployments` | List Deployments and how many copies are ready |
| `kubectl delete pod <name>` | Delete one pod |
| `kubectl scale deployment <name> --replicas=5` | Change how many copies a Deployment keeps |
| `kubectl set image deployment/<name> <container>=<image>` | Change the image of a Deployment's container |
| `kubectl get events --field-selector reason=Failed` | Show only events whose reason is `Failed` |
| `kubectl delete -f manifests/` | Delete everything the files in a folder describe |

## Going deeper

- [Kubernetes overview](https://kubernetes.io/docs/concepts/overview/)
- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- CKAD domain: Application Deployment
