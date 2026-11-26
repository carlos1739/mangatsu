# Mangatsu on Red Hat OpenShift

The application manifests are shared with Kubernetes. This directory contains the OpenShift Route that exposes the web Service. Use the project provided by the Red Hat course lab; do not create or assume a project named `mangatsu`.

## Start the course lab

For Red Hat Academy/RHLS courses, the remote Linux desktop is only a lab workstation; it is not the OpenShift Web Console. Return to the course/lab page and look for a provided **OpenShift Console**, **Web Console**, or cluster access link/instructions. The course lab guide must provide the cluster endpoint and login path. If it provides only a remote desktop and no cluster URL or console access, ask the instructor/course support whether this lab includes an OpenShift cluster. Having the `oc` command installed does not by itself mean the workstation is logged in or connected to a usable project.

Once you have opened the Web Console, use its top-right **Help (?) > Command Line Tools** page to download the matching CLI if needed. Extract it, then either add the folder containing `oc.exe` to `PATH` or run commands from that folder as `.\oc.exe`.

To log in, open the top-right user menu and select **Copy login command**. Sign in again if prompted, choose **Display Token**, and copy the provided `oc login --server=... --token=...` command. Run it in PowerShell on the PC that will run the deployment workflow. The token is private: do not paste it into chat, screenshots, workflow files, or Git. Confirm the login and note the active project:

```powershell
oc whoami
$project = oc project -q
oc status
```

If `oc whoami` reports that `system:anonymous` is forbidden, the CLI is not sending a valid login for that cluster. Repeat the console's **Copy login command** flow and run its fresh command in this terminal. Check that the command's `--server` matches the course console. Do not try to fix this with `oc adm` or by granting extra permissions; first get `oc whoami` to return your course username.

Keep the lab active while deploying. Course labs can expire or stop, so they are suitable for UAS demonstrations but should not be described as a permanent 24-hour production service.

## Deploy manually

From the repository root, create the database Secret and initialization ConfigMap in the active course project. The local `.env` file is ignored by Git:

```powershell
$project = oc project -q
oc create secret generic mangatsu-db --from-env-file=.env -n $project --dry-run=client -o yaml | oc apply -f -
oc create configmap mangatsu-db-init --from-file=init.sql=backend_manga/perpustakaan.sql -n $project --dry-run=client -o yaml | oc apply -f -
```

Apply the namespaced resources and Route:

```powershell
$manifests = @(
  "k8s/01-config.yaml",
  "k8s/02-mysql.yaml",
  "k8s/03-api.yaml",
  "k8s/04-web.yaml",
  "k8s/05-hpa.yaml",
  "k8s/06-pdb.yaml",
  "k8s/08-monitoring.yaml",
  "openshift/route.yaml"
)
foreach ($manifest in $manifests) {
  oc apply -n $project -f $manifest
}
```

Check rollout, Route, storage, and autoscaling:

```powershell
oc get pods,pvc,hpa -n $project
oc get route mangatsu -n $project
oc describe hpa api -n $project
oc top pods -n $project
```

Open the host shown by `oc get route mangatsu` to use Mangatsu. The Route terminates TLS and redirects HTTP to HTTPS. Uptime Kuma can be opened locally with:

```powershell
oc port-forward -n $project service/uptime-kuma 3001:3001
```

Create its initial admin account and monitor the in-project Services `http://web/` and `http://api:5000/api/health`.

## CI/CD target

The repository's GitHub Actions deployment is configured for the local Docker Desktop Kubernetes cluster, which is the primary UAS target. The optional OpenShift instructions on this page are for manual course-lab demonstrations; the workflow does not currently deploy to OpenShift.

## OpenShift security note

The web and API images run as non-root and the web server listens on unprivileged port `8080`. OpenShift enforces restricted container permissions; do not grant the `anyuid` SCC just to bypass a startup error. If the MySQL pod reports a data-directory permission error, stop and use the OpenShift-supported MySQL image/template supplied by the course lab, preserving the same database environment variables and persistent storage.
