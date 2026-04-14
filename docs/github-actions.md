# GitHub Actions image workflow

The repository now includes a workflow at `.github/workflows/build-images.yml`.

## Trigger behavior

- Push to `main`: builds and publishes both images automatically.
- Push to `develop`: builds and publishes both images automatically.
- Push to `feature/*`: does nothing automatically.
- Manual run with `workflow_dispatch`: can be started from any branch.

## Tag behavior

Each tag starts from the service version in `package.json`.

Examples for `serviceA` version `1.0.0`:

- `main` push: `ghcr.io/<owner>/servicea:1.0.0`
- `main` push channel tag: `ghcr.io/<owner>/servicea:latest`
- `develop` push: `ghcr.io/<owner>/servicea:1.0.0-develop.<run_number>`
- `develop` push channel tag: `ghcr.io/<owner>/servicea:develop-latest`
- manual run on `feature/OAS-1234`: `ghcr.io/<owner>/servicea:1.0.0-OAS-1234.<run_number>`
- manual run on `feature/OAS-1234` channel tag: `ghcr.io/<owner>/servicea:OAS-1234-latest`

`<run_number>` comes from the GitHub Actions run number, which makes repeated builds unique without editing `package.json`.

## Manual feature branch build

1. Create a branch from `develop`, for example `feature/OAS-1234`.
2. Push the branch to GitHub.
3. Open the `Build Images` workflow in GitHub Actions.
4. Choose the `feature/OAS-1234` branch.
5. Run the workflow.

That manual run will publish feature-specific image tags containing the Jira ticket suffix if the branch name includes a ticket key such as `OAS-1234`.
