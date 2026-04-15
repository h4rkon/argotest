# Feature Branch Environments

This repo creates temporary feature environments through a manual GitHub Action.
The workflow copies `environments/develop/values.yaml` into a feature-specific values file, then writes or removes a generated Argo CD `Application` manifest under `argocd/apps/feature-apps`.
When the feature files are removed, Argo CD prunes the namespace and its resources.

## One-time setup

1. Commit and push these files to `develop`:
   - `.github/workflows/feature-env.yml`
   - `argocd/apps/feature-apps/.gitkeep`
   - `environments/develop/values.yaml`
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
   This writes:
   - `environments/feature-oas-1234/values.yaml`
   - `argocd/apps/feature-apps/feature-oas-1234.yaml`
   on `develop`.
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

## Update one service in a feature environment

Once the feature environment exists, you can update a single service image without recreating the environment.

Run the `Update Feature Environment` workflow with:

- `branch`: `feature/OAS-1234`
- `service`: `servicea` or `serviceb`
- `image_tag`: for example `OAS-1234-latest` or `1.0.0-OAS-1234.27`

This updates only that service inside:

- `environments/feature-oas-1234/values.yaml`

Argo CD then syncs the changed image into the running feature environment.

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

1. Check the generated files exist on `develop`:
   ```bash
   ls argocd/apps/feature-apps
   ls environments/feature-oas-1234
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
5. Check the feature values file if a single-service update did not apply:
   ```bash
   sed -n '1,200p' environments/feature-oas-1234/values.yaml
   ```
