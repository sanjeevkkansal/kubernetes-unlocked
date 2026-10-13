# Episode 1 solution: 4 replicas from the file

Edit `manifests/nginx-deployment.yaml` and change one line:

```yaml
spec:
  replicas: 4
```

Then:

```bash
kubectl apply -f manifests/nginx-deployment.yaml
kubectl get deployment nginx-deployment
./verify.sh
```

```
deployment.apps/nginx-deployment configured
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   4/4     4            4           2m
```

Change it back to 3 when you are done, so the next episode starts from the same place.
