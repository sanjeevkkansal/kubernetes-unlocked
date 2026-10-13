# Episode 4: Pods in Depth

Video: coming soon  |  Lab time: about 35 minutes

Phase 1: Foundations  |  Previous: [Episode 3](../03-architecture/)  |  Next: Episode 5 (coming soon)

## What you will be able to do

- Read any Kubernetes object as apiVersion, kind, metadata, spec and status, and write a pod
  manifest with `kubectl run --dry-run=client -o yaml` and `kubectl explain`.
- Follow a pod through its phases, and tell the phase from the STATUS column.
- Use `kubectl logs`, `kubectl exec` and `kubectl describe` to see inside a pod.
- Run an init container before the app, and a sidecar beside it.
- Read a CrashLoopBackOff: the exit code, the logs of the run that died, and the back-off.

## Before you start

You need the cluster from [Episode 2](../02-local-cluster/). This lab runs in the `default`
namespace. Run every command from this folder:

```bash
cd episodes/04-pods
../../cluster/up.sh
```

Pod names, ages, IPs and times will differ on your machine. Everything else should match.

---

## Part 1: write and read a pod

### Step 1: let kubectl write the YAML

Nobody memorises pod YAML. Ask kubectl to build it, without sending it anywhere:

```bash
kubectl run web --image=nginx:1.30.5-alpine --dry-run=client -o yaml
```

```
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: web
  name: web
spec:
  containers:
  - image: nginx:1.30.5-alpine
    name: web
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}
```

`kubectl run web` makes a pod named `web`. `--dry-run=client` builds the object on your machine and
sends nothing to the cluster. `-o yaml` prints it. [manifests/web.yaml](manifests/web.yaml) is
this output, trimmed, with the image pinned by digest.

Which fields can a container take? `kubectl explain` reads the documentation built into the API:

```bash
kubectl explain pod.spec.containers | wc -l
kubectl explain pod.spec.containers | grep -E '^  [a-z]'
```

```
     198
  args	<[]string>
  command	<[]string>
  env	<[]EnvVar>
  envFrom	<[]EnvFromSource>
  image	<string>
  imagePullPolicy	<string>
  ...
  volumeMounts	<[]VolumeMount>
  workingDir	<string>
```

198 lines of documentation. The `grep` keeps only lines that start with exactly two spaces and a
letter: the field names. The path `pod.spec.containers` is read left to right, into the object.

### Step 2: what the cluster adds

The lab's file is the dry-run output, trimmed, with the image pinned:

```bash
cat manifests/web.yaml
```

```bash
kubectl apply -f manifests/web.yaml
kubectl get pod web -o yaml | wc -l
kubectl get pod web -o yaml | grep -E '^[a-z]'
```

```
pod/web created
     137
apiVersion: v1
kind: Pod
metadata:
spec:
status:
```

What just happened: a 10-line file came back as 137 lines. Run `kubectl get pod web -o yaml`
without the pipes to read them. The cluster filled in defaults under `spec`, and added `status`.
Every object has these five parts: `apiVersion` and `kind` say what it is, `metadata` names it,
`spec` is what you want, and `status` is what is true now. You write `spec`. The cluster writes
`status`.

---

## Part 2: phases

### Step 3: two pods that run once

[manifests/run-once.yaml](manifests/run-once.yaml) has two pods with `restartPolicy: Never`. One
exits 0, the other exits 3. `-w` keeps watching and prints a line on every change; press Ctrl-C
to stop it. Read the file first; `---` separates the two pods:

```bash
cat manifests/run-once.yaml
kubectl apply -f manifests/run-once.yaml
kubectl get pods -w
```

```
pod/succeeds created
pod/fails created
NAME       READY   STATUS              RESTARTS      AGE
fails      0/1     ContainerCreating   0             0s
succeeds   0/1     ContainerCreating   0             0s
succeeds   1/1     Running             0             0s
fails      1/1     Running             0             0s
succeeds   0/1     Completed           0             4s
fails      0/1     Error               0             4s
```

STATUS is a summary written for people. The field Kubernetes itself tracks is the phase:

```bash
kubectl get pods -o custom-columns=NAME:.metadata.name,PHASE:.status.phase
```

```
NAME       PHASE
fails      Failed
succeeds   Succeeded
web        Running
```

What just happened: `Completed` is phase `Succeeded`, and this `Error` is phase `Failed`. There are
five phases: Pending, Running, Succeeded, Failed and Unknown. STATUS has many more words.

---

## Part 3: look inside

### Step 4: logs, exec and describe

```bash
kubectl logs web | head -3
kubectl exec web -- nginx -v
```

```
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
nginx version: nginx/1.30.5
```

`kubectl logs` prints what the container wrote to its output. `kubectl exec` runs a command inside
the container; `--` ends kubectl's own flags, and everything after it is the command. With `-it`
you get an interactive shell:

```bash
kubectl exec -it web -- sh
```

Your prompt changes to `/ #`: you are inside the container. Run:

```bash
ps
exit
```

```
PID   USER     TIME  COMMAND
    1 root      0:00 nginx: master process nginx -g daemon off;
   34 nginx     0:00 nginx: worker process
...
```

nginx is process 1, with one worker per CPU. `kubectl describe` shows the pod's state, its
containers and its recent events in one place. It is long; `grep -A3` keeps the line that matches
and the three after it:

```bash
kubectl describe pod web | grep -A3 State
```

```
    State:          Running
      Started:      Sun, 11 Oct 2026 18:57:21 +0000
    Ready:          True
    Restart Count:  0
```

Run `kubectl describe pod web` without the `grep` to see all of it. The Events table at the
bottom lists what happened to the pod, and who did it.

---

## Part 4: helper containers

### Step 5: an init container

[manifests/web-init.yaml](manifests/web-init.yaml) has an init container, `write-page`, that writes
an HTML page into a shared `emptyDir` volume and exits. nginx starts only after it finishes, and
serves that page.

```bash
cat manifests/web-init.yaml
kubectl apply -f manifests/web-init.yaml
kubectl get pod web-init -w
```

```
pod/web-init created
NAME       READY   STATUS     RESTARTS   AGE
web-init   0/1     Init:0/1   0          0s
web-init   0/1     PodInitializing   0          11s
web-init   1/1     Running           0          11s
```

`Init:0/1` means zero of one init containers have finished. Press Ctrl-C, then fetch the page from
inside the pod:

```bash
kubectl exec web-init -- wget -qO- localhost
```

```
Defaulted container "nginx" out of: nginx, write-page (init)
<h1>Written by an init container</h1>
```

The first line is kubectl telling you the pod has two containers and it picked `nginx`. To pick
one yourself, add `-c <container>`.

### Step 6: a sidecar

[manifests/sidecar.yaml](manifests/sidecar.yaml) runs nginx with a sidecar, `log-shipper`, that
follows nginx's access log. A sidecar is an init container with `restartPolicy: Always`: it starts
first and keeps running beside the app.

```bash
cat manifests/sidecar.yaml
kubectl apply -f manifests/sidecar.yaml
kubectl get pod sidecar
kubectl exec sidecar -- wget -qO- localhost | grep title
kubectl exec sidecar -- wget -qO- localhost/missing
kubectl logs sidecar -c log-shipper
```

```
pod/sidecar created
NAME      READY   STATUS    RESTARTS   AGE
sidecar   2/2     Running   0          0s
<title>Welcome to nginx!</title>
wget: server returned error: HTTP/1.1 404 Not Found
tail: can't open '/var/log/nginx/access.log': No such file or directory
tail: /var/log/nginx/access.log has appeared; following end of new file
::1 - - [11/Oct/2026:16:36:13 +0000] "GET / HTTP/1.1" 200 896 "-" "Wget" "-"
::1 - - [11/Oct/2026:16:36:13 +0000] "GET /missing HTTP/1.1" 404 153 "-" "Wget" "-"
```

What just happened: READY is `2/2`, because the sidecar counts. The sidecar saw both requests, the
200 and the 404. Because the log directory is now a shared volume, nginx's own `kubectl logs
sidecar` shows only its startup lines. A plain second container in `containers:` would also run
beside nginx, but it would keep a pod that should finish running forever; the exercise shows this.

---

## Part 5: a pod that keeps crashing

### Step 7: read a CrashLoopBackOff

[manifests/api.yaml](manifests/api.yaml) is a pretend API that needs a database address.

```bash
kubectl apply -f manifests/api.yaml
kubectl get pods -w
```

```
pod/api created
NAME   READY   STATUS              RESTARTS   AGE
api    0/1     ContainerCreating   0          0s
api    1/1     Running             0          0s
api    0/1     Error               0          1s
api    1/1     Running             1 (1s ago)   1s
api    0/1     Error               1 (2s ago)   2s
api    0/1     CrashLoopBackOff    1 (14s ago)   15s
api    1/1     Running             2 (14s ago)   15s
api    0/1     Error               2 (15s ago)   16s
api    0/1     CrashLoopBackOff    2 (24s ago)   39s
api    1/1     Running             3 (24s ago)   39s
api    0/1     Error               3 (25s ago)   40s
```

It starts, fails within a second, and the kubelet restarts it, waiting longer each time (10 s,
20 s, 40 s and so on, up to 5 minutes). `CrashLoopBackOff` is that wait. The phase stays
`Running` the whole time. Press Ctrl-C, then ask why, in this order:

```bash
kubectl describe pod api | grep -A3 'Last State'
kubectl logs api
```

```
    Last State:     Terminated
      Reason:       Error
      Exit Code:    1
starting api
FATAL: DATABASE_URL is not set
```

`Last State` is how the previous run ended: exit code 1. `kubectl logs` shows the most recent run.
Once the container has restarted, `kubectl logs api --previous` shows the run before it. While
STATUS says `Error`, the run that failed is still the current one, so `--previous` can fail with
`unable to retrieve container logs`. Plain `kubectl logs` is the one to try first.

### Step 8: fix it

The app needs `DATABASE_URL`. Find where environment variables go:

```bash
kubectl explain pod.spec.containers.env | head -12
```

```
KIND:       Pod
VERSION:    v1

FIELD: env <[]EnvVar>


DESCRIPTION:
    List of environment variables to set in the container. Cannot be updated.
    EnvVar represents an environment variable present in a Container.

FIELDS:
  name	<string> -required-
```

"Cannot be updated." [manifests/api-fixed.yaml](manifests/api-fixed.yaml) adds the variable:

```bash
diff manifests/api.yaml manifests/api-fixed.yaml
```

```
1c1
< # A pretend API that needs a database address. Without DATABASE_URL it exits with code 1.
---
> # The same pod with DATABASE_URL set.
9a10,12
>       env:
>         - name: DATABASE_URL
>           value: postgres://db:5432/unlocked
```

Try to apply it:

```bash
kubectl apply -f manifests/api-fixed.yaml
```

```
The Pod "api" is invalid: spec: Forbidden: pod updates may not change fields other than `spec.containers[*].image`, ...
```

Most of a running pod's spec cannot change. `kubectl replace --force` deletes the pod and creates
it again from the file:

```bash
kubectl replace --force -f manifests/api-fixed.yaml
kubectl logs api
```

```
pod "api" deleted from default namespace
pod/api replaced
starting api
connected to postgres://db:5432/unlocked
```

Deleting and recreating pods by hand is exactly the job Deployments take over. That is a later
episode.

---

## Check your work

```bash
./verify.sh
```

```
Episode 4: Pods in Depth

  PASS  kubectl is pointed at the series cluster (kind-unlocked)
  PASS  web is Running, with the pinned nginx image
  PASS  succeeds finished with phase Succeeded
  PASS  fails finished with phase Failed and exit code 3
  PASS  web-init: the init container finished, and nginx serves the page it wrote
  PASS  sidecar: log-shipper is a native sidecar, running, and READY is 2/2
  PASS  api is fixed: Running, no restarts, and connected
  PASS  web-init-broken is gone or fixed

All 8 checks passed.
```

A `FAIL` line comes with the exact command to run.

---

## Break it on purpose

[manifests/web-init-broken.yaml](manifests/web-init-broken.yaml) is `web-init` with one typo in the
init container's path.

```bash
kubectl apply -f manifests/web-init-broken.yaml
kubectl get pod web-init-broken -w
```

```
pod/web-init-broken created
NAME              READY   STATUS     RESTARTS   AGE
web-init-broken   0/1     Init:0/1   0          0s
web-init-broken   0/1     Init:Error   0          11s
web-init-broken   0/1     Init:0/1     1 (0s ago)   11s
web-init-broken   0/1     Init:Error   1 (11s ago)   22s
web-init-broken   0/1     Init:CrashLoopBackOff   1 (13s ago)   34s
```

nginx never starts. Press Ctrl-C and ask for the logs:

```bash
kubectl logs web-init-broken
kubectl logs web-init-broken -c write-page
```

```
Error from server (BadRequest): container "nginx" in pod "web-init-broken" is waiting to start: PodInitializing
sh: line 0: can't create /wrok/index.html: nonexistent directory
```

The first command asks nginx, which has not started. `-c write-page` asks the init container,
which has the answer: `/wrok` instead of `/work`. `./verify.sh` now fails its last check and says
how to remove the broken pod.

---

## Try this yourself

Write a pod from scratch with `kubectl run --dry-run=client -o yaml`. Its main container prints
`working`, sleeps 20 seconds and exits 0, with `restartPolicy: Never`. Add a native sidecar that
prints the date every 5 seconds. Predict its final phase and STATUS, then check with
`kubectl get pods` and the custom-columns command from Step 3. Then move the sidecar into
`containers:` and explain why the pod never finishes. Answer in [solutions/](solutions/).

## Quiz

1. Which part of an object do you write, and which does the cluster write?
2. A pod shows STATUS `CrashLoopBackOff`. What is its phase?
3. `kubectl logs api --previous` fails with `unable to retrieve container logs`. What do you run
   instead, and why?
4. An init container's script ends with `echo done`, and the step that writes the page fails
   before that. What do you see?
5. Why can `kubectl apply` not add an environment variable to a running pod?

<details>
<summary>Answers</summary>

1. You write `spec`. The cluster writes `status`.
2. `Running`. The container keeps being restarted; the pod is still running.
3. `kubectl logs api`. While STATUS shows `Error`, the failed run is still the current container;
   `--previous` works once it has restarted.
4. The init container exits 0 (the exit code of `echo`), shows `Completed`, and the app starts with
   whatever was missing. Make the command fail when any step fails.
5. Most of a pod's spec cannot change after it is created. Replace the pod, or let a Deployment do
   it.

</details>

## Clean up

```bash
kubectl delete -f manifests/ --ignore-not-found --wait=false
```

`--wait=false` returns straight away instead of waiting for each pod to stop.

## Commands in this episode

| Command | What it does |
|---------|--------------|
| `cat <file>` | Print a file, to read a manifest before you apply it |
| `diff <file-a> <file-b>` | Show what changed between two files |
| `kubectl run web --image=<image> --dry-run=client -o yaml` | Print the YAML for a pod without creating it |
| `kubectl explain pod.spec.containers` | Every field a container takes, with its documentation |
| `kubectl explain pod.spec.containers.env` | How to set environment variables |
| `kubectl get pod web -o yaml` | The live object: your spec, the defaults, and the status |
| `kubectl get pods -w` | Keep listing, one line per change (Ctrl-C to stop) |
| `kubectl get pods -o custom-columns=NAME:.metadata.name,PHASE:.status.phase` | Each pod's phase |
| `kubectl logs web` | What the container printed |
| `kubectl logs sidecar -c log-shipper` | One container's output, in a pod with several |
| `kubectl logs api --previous` | The run before this one, once the container has restarted |
| `kubectl exec web -- nginx -v` | Run one command inside the container |
| `kubectl exec -it web -- sh` | Open a shell inside the container (`exit` to leave) |
| `kubectl describe pod web` | State, containers and recent events in one place |
| `kubectl describe pod api \| grep -A3 'Last State'` | How the previous run ended |
| `kubectl replace --force -f <file>` | Delete the pod and create it again from the file |
| `kubectl delete -f manifests/ --wait=false` | Delete what the files describe, without waiting |

## Going deeper

- [Pod lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
- [Init containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [Sidecar containers](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)
- CKAD domains: Application Design and Build, Application Observability and Maintenance
