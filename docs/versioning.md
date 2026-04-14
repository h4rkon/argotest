# Versioning

Each service uses the `version` field in its own `package.json` as the source of truth for semantic versioning.

## Bump a service version

Patch:

```bash
cd services/serviceA && npm run version:patch
```

Minor:

```bash
cd services/serviceA && npm run version:minor
```

Major:

```bash
cd services/serviceA && npm run version:major
```

Do the same for `serviceB` from `services/serviceB`.

## Build an image with semantic tags

By default, the image name is the lowercase service name and the tags are:

- `<version>`
- `latest`

Example:

```bash
cd services/serviceA && npm run image:build
```

That builds:

- `servicea:1.0.0`
- `servicea:latest`

To build for a registry path, override `IMAGE_NAME`:

```bash
cd services/serviceA && IMAGE_NAME=ghcr.io/<owner>/servicea npm run image:build
```

That builds:

- `ghcr.io/<owner>/servicea:1.0.0`
- `ghcr.io/<owner>/servicea:latest`

## GitHub Actions tags

The GitHub Actions workflow adds branch-aware tags on top of the base service version:

- `main`: stable release tag, for example `1.0.0`
- `develop`: prerelease tag, for example `1.0.0-develop.42`
- `feature/OAS-1234`: feature tag, for example `1.0.0-OAS-1234.42`

See `docs/github-actions.md` for the workflow behavior.
