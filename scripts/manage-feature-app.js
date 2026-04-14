const fs = require('fs');
const path = require('path');

const [action, branch] = process.argv.slice(2);

if (!action || !branch) {
  console.error('Usage: node scripts/manage-feature-app.js <create|delete> <branch>');
  process.exit(1);
}

const jiraMatch = branch.match(/([A-Z]+-\d+)/);
if (!jiraMatch) {
  console.error(`Branch "${branch}" does not contain a Jira key like OAS-1234.`);
  process.exit(1);
}

const jiraKey = jiraMatch[1];
const normalize = (value) =>
  value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

const namespace = normalize(branch);
const appName = `feature-${normalize(jiraKey)}`;

const repoRoot = path.resolve(__dirname, '..');
const appsDir = path.join(repoRoot, 'argocd', 'feature-apps');
const appPath = path.join(appsDir, `${appName}.yaml`);

if (action === 'delete') {
  if (fs.existsSync(appPath)) {
    fs.unlinkSync(appPath);
    console.log(`Deleted ${path.relative(repoRoot, appPath)}`);
  } else {
    console.log(`No app manifest found at ${path.relative(repoRoot, appPath)}`);
  }
  process.exit(0);
}

if (action !== 'create') {
  console.error(`Unknown action "${action}". Use create or delete.`);
  process.exit(1);
}

fs.mkdirSync(appsDir, { recursive: true });

const manifest = `apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${appName}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/h4rkon/argotest.git
    targetRevision: ${branch}
    path: kubernetes/feature
    kustomize:
      images:
        - ghcr.io/h4rkon/servicea:${jiraKey}-latest
        - ghcr.io/h4rkon/serviceb:${jiraKey}-latest
  destination:
    server: https://kubernetes.default.svc
    namespace: ${namespace}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
`;

fs.writeFileSync(appPath, manifest, 'utf8');
console.log(`Wrote ${path.relative(repoRoot, appPath)}`);
