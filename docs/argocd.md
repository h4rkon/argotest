# Argo CD app of apps

This repo contains a simple app-of-apps setup for Argo CD.

## Layout

- `argocd/root-application.yaml`: root application to bootstrap the child apps
- `argocd/apps/develop`: child apps for the `develop` environment
- `argocd/apps/main`: child apps for the `main` environment
- `kubernetes/serviceA/base` and `kubernetes/serviceB/base`: shared manifests
- `kubernetes/serviceA/overlays/*` and `kubernetes/serviceB/overlays/*`: environment-specific overlays

## Namespace creation

All child applications set:

```yaml
syncOptions:
  - CreateNamespace=true
```

That allows Argo CD to create the destination namespace automatically if it does not already exist.

Environment mapping:

- `develop` Applications track the `develop` branch and deploy to the `develop` namespace
- `main` Applications track the `main` branch and deploy to the `main` namespace

## Images

The overlays pin different rolling tags per environment:

- `develop` uses `ghcr.io/h4rkon/servicea:develop-latest` and `ghcr.io/h4rkon/serviceb:develop-latest`
- `main` uses `ghcr.io/h4rkon/servicea:latest` and `ghcr.io/h4rkon/serviceb:latest`

## Access

Each overlay also creates an Ingress for the existing `ingress-nginx` controller in Colima.

Expected URLs:

- `http://servicea-develop.192.168.5.1.sslip.io/hello`
- `http://serviceb-develop.192.168.5.1.sslip.io/hello`
- `http://servicea-main.192.168.5.1.sslip.io/hello`
- `http://serviceb-main.192.168.5.1.sslip.io/hello`

## Bootstrap

Apply the root app into the existing Argo CD installation:

```bash
kubectl apply -f argocd/root-application.yaml
```

With the current root app definition, Argo CD reads the app-of-apps structure from the `develop` branch and creates both environment groups.

## Port forward

For reliable local access in Colima, use the repo Makefile:

```bash
make port-forward-open
make port-forward-check
make call-services
make port-forward-close
```

URLs:

- `http://localhost:18081/hello` for `serviceA` in `develop`
- `http://localhost:18082/hello` for `serviceB` in `develop`
- `http://localhost:18083/hello` for `serviceA` in `main`
- `http://localhost:18084/hello` for `serviceB` in `main`

## Feature branches

Feature branches can be deployed as temporary environments via an ApplicationSet.
This creates a namespace per branch and removes it when the branch is deleted.

Branch matching:

- `feature/*`

Namespace:

- uses the normalized branch name (slashes replaced and lowercased)

Image tags:

- Jira key extracted from the branch name, for example `OAS-1234-latest`

The ApplicationSet definition is in:

- `argocd/apps/feature-branches-appset.yaml`

To enable it, create a GitHub token secret in `argocd`:

```bash
kubectl -n argocd create secret generic github-token \
  --from-literal=token='<your_github_token>'
```
