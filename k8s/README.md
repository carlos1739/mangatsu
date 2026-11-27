# Mangatsu on Kubernetes

These manifests deploy the web frontend and API as replicated Deployments, MySQL as a single-replica StatefulSet backed by a persistent volume claim, and Uptime Kuma for HTTP availability monitoring. The primary UAS target is the existing local Docker Desktop Kubernetes cluster. Optional OpenShift course-lab notes are in [`openshift/README.md`](../openshift/README.md).

## Prerequisites

- Docker Desktop Kubernetes is running and `kubectl get nodes` reports `Ready`.
- Docker images `carlossiregar/mangatsu-api:1.1` and `carlossiregar/mangatsu-web:1.1` are accessible.
- The ignored root `.env` file contains `MYSQL_ROOT_PASSWORD`, `DB_NAME`, `DB_USER`, and `DB_PASSWORD`. Do not commit this file or generated Secret YAML.

Docker-built images are not automatically available inside the Kubernetes node. Use images already pushed to Docker Hub; the GitHub Actions workflow builds and publishes them before deploying.

## Deploy locally

Create the namespace and Kubernetes Secret from the local environment file. This sends the Secret directly to the cluster without writing its values to a tracked file:

```powershell
kubectl apply -f k8s/00-namespace.yaml
kubectl create secret generic mangatsu-db --from-env-file=.env -n mangatsu --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap mangatsu-db-init --from-file=init.sql=backend_manga/perpustakaan.sql -n mangatsu --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n mangatsu -f k8s/
```

Wait for the database, API, and web pods:

```powershell
kubectl get pods -n mangatsu -w
```

Open another terminal and forward the web Service to `http://localhost:8080`:

```powershell
kubectl port-forward -n mangatsu service/web 8080:80
```

The Nginx frontend proxies `/api` requests to the `api` Service inside the cluster.
The web container waits for the `api` Service DNS entry before starting Nginx, and its startup probe allows up to five minutes for that dependency to become available. This avoids a crash loop if the cluster DNS is not ready immediately after a node restart.

## HPA metrics

The HPA resources require the Kubernetes Metrics API. If `kubectl top nodes` reports that the Metrics API is unavailable, install Metrics Server and allow it to use the local cluster's kubelet certificates:

```powershell
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json --patch-file=scripts/metrics-server-patch.json
kubectl rollout status deployment/metrics-server -n kube-system
kubectl top nodes
```

Then confirm HPA status and test scaling with a bounded 90-second load job against the API health endpoint:

```powershell
kubectl apply -n mangatsu -f scripts/hpa-load-test.yaml
kubectl get hpa -n mangatsu
kubectl get hpa -n mangatsu -w
kubectl describe hpa api -n mangatsu
```

The job stops automatically; remove it after the demonstration so it can be run again:

```powershell
kubectl delete job hpa-load-test -n mangatsu
```

The local cluster has one node. It can demonstrate multiple replicas and HPA, but it does not provide node-level high availability. MySQL remains at one replica to protect write consistency; its data is persisted on the PVC.

## Monitoring with Uptime Kuma

Forward the monitoring Service and open `http://localhost:3001`:

```powershell
kubectl port-forward -n mangatsu service/uptime-kuma 3001:3001
```

Create the initial admin account in the UI, then add HTTP monitors for:

- Frontend: `http://web/`
- API health: `http://api:5000/api/health`

These service names resolve inside the `mangatsu` namespace. The Uptime Kuma database is persisted on its PVC. `kubectl top pods -n mangatsu` and the HPA view show CPU usage and replica counts.

## Update images

The GitHub Actions workflow publishes commit-specific images. To deploy those images manually after a successful workflow run:

```powershell
kubectl set image deployment/api api=carlossiregar/mangatsu-api:sha-COMMIT_SHA -n mangatsu
kubectl set image deployment/web web=carlossiregar/mangatsu-web:sha-COMMIT_SHA -n mangatsu
kubectl rollout status deployment/api -n mangatsu
kubectl rollout status deployment/web -n mangatsu
```

GitHub Actions builds and pushes commit-specific images on GitHub-hosted runners. On the repository's default `master` branch, it can also deploy to this local cluster using a self-hosted Windows runner. The workflow renders the API and web manifests with the exact commit image tags before applying them, so it does not first roll out stale `1.1` images:

1. In **Settings > Actions > Runners**, choose **New self-hosted runner**, select Windows x64, and follow GitHub's setup commands on this PC. Add the custom label `mangatsu-kubernetes`; do not share the temporary registration token.
2. Run the runner under the same Windows account whose `kubectl config current-context` is `docker-desktop`. Keep Docker Desktop Kubernetes and the runner online.
3. In **Settings > Secrets and variables > Actions > Variables**, add `K8S_DEPLOY_ENABLED=true`.
4. In the **Secrets** tab, add `MYSQL_ROOT_PASSWORD`, `DB_NAME`, `DB_USER`, and `DB_PASSWORD`. `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` are also required by the image build job.
5. Merge a trusted change to `master`. The deploy job applies the manifests, updates API/web to the commit-specific images, and waits for both rollouts.

The runner uses its local Kubernetes credentials; do not store a kubeconfig or database Secret in GitHub or the repository. Restrict write access and never run untrusted pull-request workflows on this self-hosted runner. Since the cluster and runner are on the same PC, this supports a CI/CD demonstration but is not a hosted 24-hour service.

## Useful checks

```powershell
kubectl get all,pvc,hpa,pdb -n mangatsu
kubectl logs deployment/api -n mangatsu
kubectl describe pod -n mangatsu
```
