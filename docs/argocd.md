# Argo CD app of apps

This repo contains a simple app-of-apps setup for Argo CD.

## Layout

- `argocd/root-application.yaml`: root application to bootstrap the child apps
- `argocd/apps/develop/environment-application.yaml`: Argo CD app for the `develop` environment
- `argocd/apps/feature-apps`: generated feature environment apps
- `argocd/apps/main/environment-application.yaml`: Argo CD app for the `main` environment
- `helm/argotest-environment`: shared Helm chart for all environment deployments
- `environments/develop/values.yaml` and `environments/main/values.yaml`: explicit environment image state

## Namespace creation

All child applications set:

```yaml
syncOptions:
  - CreateNamespace=true
```

That allows Argo CD to create the destination namespace automatically if it does not already exist.

Environment mapping:

- `develop-environment` tracks the `develop` branch and deploys to the `develop` namespace
- feature environment apps track their own feature branch and deploy to a normalized feature namespace such as `feature-oas-4714`
- `main-environment` tracks the `main` branch and deploys to the `main` namespace

## Images

The environment values files define the exact image state:

- `environments/develop/values.yaml` uses `develop-latest`
- `environments/main/values.yaml` uses `latest`

This is the baseline for the next feature-environment iteration, where a feature values file can start as a copy of `develop` and then override only the services built for that feature branch.

The current feature environment flow now works from a copied develop state:

- the `Feature Environment` GitHub Actions workflow copies `environments/develop/values.yaml`
- it writes the copy to `environments/feature-oas-4714/values.yaml` with only the namespace changed
- it generates an Argo CD `Application` in `argocd/apps/feature-apps`
- that feature app tracks `develop` and reads the generated feature values file

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

Feature environments require an explicit namespace when port-forwarding:

```bash
FEATURE_NAME=feature-oas-4715 make feature-open
FEATURE_NAME=feature-oas-4715 make feature-check
FEATURE_NAME=feature-oas-4715 make call-feature
FEATURE_NAME=feature-oas-4715 make feature-close
```

Optional port override:

```bash
FEATURE_NAME=feature-oas-4715 FEATURE_PORT_A=19085 FEATURE_PORT_B=19086 make feature-open
```

## Feature environments

Feature environments are created manually through the workflow in `.github/workflows/feature-env.yml`.

Flow:

1. Push a feature branch such as `feature/OAS-4714`
2. Run `Build Images` on that branch so `OAS-4714-latest` exists for the services you need
3. Run `Feature Environment` with:
   - `action = create`
   - `branch = feature/OAS-4714`
4. The workflow commits:
   - `environments/feature-oas-4714/values.yaml`
   - `argocd/apps/feature-apps/feature-oas-4714.yaml`
5. Argo CD creates namespace `feature-oas-4714` and deploys the feature app from the copied develop values

Cleanup:

1. Delete the feature branch
2. Run `Feature Environment` with:
   - `action = delete`
   - `branch = feature/OAS-4714`
3. Argo CD prunes the app and namespace

## Current state model

`develop` and `main` are now single environment apps backed by explicit values files, not four separate hardcoded service apps.

That matters because it gives you a clear base state for later preview logic:

- copy the current `develop` state into a feature values file
- override only the services that have a matching feature build
- leave all other services on the copied `develop` versions
