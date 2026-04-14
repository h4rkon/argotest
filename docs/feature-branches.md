# Feature Branch Environments (Argo CD ApplicationSet)

This repo can create a temporary namespace and Argo CD Application per feature branch via a manual GitHub Action.
When the branch is deleted, you remove the manifest and Argo CD prunes the resources and namespace.

## One-time setup

1. Commit and push these files to `develop`:
   - `argocd/apps/feature-branches-appset.yaml`
   - `kubernetes/feature/kustomization.yaml`
2. Ensure the ApplicationSet CRD exists:
   ```bash
   kubectl get crd applicationsets.argoproj.io
   ```
3. Create the GitHub token secret in `argocd`:
   ```bash
   kubectl -n argocd create secret generic github-token \
     --from-literal=token='<your_github_token>'
   ```
4. Refresh the root app so it picks up the ApplicationSet:
   ```bash
   kubectl -n argocd patch application argotest-root \
     -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' \
     --type merge
   ```
5. Verify the ApplicationSet is present:
   ```bash
   kubectl -n argocd get applicationsets
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
   This writes an app manifest under `argocd/feature-apps` on `develop`.
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

1. Check the app manifest exists on `develop` under `argocd/feature-apps`.
   ```bash
   kubectl -n argocd get applicationsets
   ```
2. Check the ApplicationSet controller logs:
   ```bash
   kubectl -n argocd logs deploy/argocd-applicationset-controller --tail=100
   ```
3. Confirm at least one `feature/*` branch exists on GitHub.
