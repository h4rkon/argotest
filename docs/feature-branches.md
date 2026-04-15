# Feature Branch Environments

This repo creates temporary feature environments through a manual GitHub Action.
The workflow writes or removes generated Argo CD `Application` manifests under `argocd/apps/feature-apps`.
When a feature app manifest is removed, Argo CD prunes the namespace and its resources.

## One-time setup

1. Commit and push these files to `develop`:
   - `.github/workflows/feature-env.yml`
   - `argocd/apps/feature-apps/.gitkeep`
   - `kubernetes/feature/kustomization.yaml`
   - `scripts/manage-feature-app.js`
2. Refresh the root app so it picks up feature apps from Git:
   ```bash
   kubectl -n argocd patch application argotest-root \
     -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' \
     --type merge
   ```
3. Verify the root app is healthy:
   ```bash
   kubectl -n argocd get application argotest-root
   ```

## Per-feature flow (every new branch)

1. Create a feature branch from `develop`:
   ```bash
   git switch develop
   git pull
   git switch -c feature/OAS-1234
   ```
2. Make your changes and push the branch:
   ```bash
   git push -u origin feature/OAS-1234
   ```
3. Run the `Build Images` GitHub Action manually on that branch:
   - Branch: `feature/OAS-1234`
   - `push_images=true`

   This produces image tags like:
   - `ghcr.io/h4rkon/servicea:OAS-1234-latest`
   - `ghcr.io/h4rkon/serviceb:OAS-1234-latest`
4. Run the `Feature Environment` workflow:
   - `action`: `create`
   - `branch`: `feature/OAS-1234`
   This writes an app manifest under `argocd/apps/feature-apps` on `develop`.
5. Argo CD creates a namespace and app automatically.
   Check:
   ```bash
   kubectl -n argocd get applications | grep feature
   kubectl get ns | grep feature
   ```
6. Verify workloads:
   ```bash
   kubectl -n feature-oas-1234 get deploy,svc,pods
   ```
7. Optional local access:
   ```bash
   make feature-open FEATURE_NS=feature-oas-1234
   make feature-check FEATURE_NS=feature-oas-1234
   ```

## Namespace naming

Kubernetes namespaces cannot contain `/`, so the branch name is normalized.
Example:

- Branch: `feature/OAS-1234`
- Namespace: `feature-oas-1234`

## Cleanup

1. Delete the feature branch:
   ```bash
   git push origin --delete feature/OAS-1234
   ```
2. Run the `Feature Environment` workflow with:
   - `action`: `delete`
   - `branch`: `feature/OAS-1234`
3. Argo CD removes the Application and prunes the namespace automatically.

## Troubleshooting

If no feature apps appear:

1. Check the app manifest exists on `develop` under `argocd/apps/feature-apps`.
   ```bash
   ls argocd/apps/feature-apps
   ```
2. Check that the generated app exists in Argo CD:
   ```bash
   kubectl -n argocd get applications | grep feature
   ```
3. Check the generated app directly:
   ```bash
   kubectl -n argocd get application feature-oas-1234
   ```
4. Check the namespace and workloads:
   ```bash
   kubectl -n feature-oas-1234 get deploy,svc,pods
   ```
