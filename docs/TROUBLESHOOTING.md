# Troubleshooting

Every problem the labs can produce, and the fix. Grows from real reports.

## `./cluster/up.sh` says Docker is not running

Start Docker Desktop (or the Docker service on Linux) and wait until `docker info` works.

## `kind create cluster` fails or hangs on the node image

Check `kind version`. This repo needs v0.33.0 or later for the pinned Kubernetes 1.37 image.

## `kubectl` talks to the wrong cluster

```bash
kubectl config use-context kind-unlocked
```

## A pod shows `ErrImagePull` or `ImagePullBackOff`

The image name or tag is wrong, or the machine cannot reach the registry. Read the reason:

```bash
kubectl get events --field-selector reason=Failed
```

## Port 8080 is already in use (Episode 1, Part 1)

Something else on your machine uses it. Stop that process, or edit the port in
`scripts/docker-pain-demo.sh`.
