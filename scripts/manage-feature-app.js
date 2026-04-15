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
const appsDir = path.join(repoRoot, 'argocd', 'apps', 'feature-apps');
const envDir = path.join(repoRoot, 'environments', namespace);
const appPath = path.join(appsDir, `${appName}.yaml`);
const valuesPath = path.join(envDir, 'values.yaml');
const developValuesPath = path.join(repoRoot, 'environments', 'develop', 'values.yaml');

const replaceNamespace = (content, nextNamespace) => {
  if (!/^namespace:/m.test(content)) {
    throw new Error('Expected values file to contain a namespace field.');
  }

  return content.replace(/^namespace:.*$/m, `namespace: ${nextNamespace}`);
};

const replaceIngressHosts = (content, nextNamespace) => {
  const lines = content.split('\n');
  let currentService = null;

  const nextLines = lines.map((line) => {
    const serviceMatch = line.match(/^  ([a-z0-9-]+):$/);
    if (serviceMatch) {
      currentService = serviceMatch[1];
      return line;
    }

    if (currentService && line.trimStart().startsWith('host: ')) {
      return `      host: ${currentService}-${nextNamespace}.192.168.5.1.sslip.io`;
    }

    return line;
  });

  return nextLines.join('\n');
};

if (action === 'delete') {
  if (fs.existsSync(appPath)) {
    fs.unlinkSync(appPath);
    console.log(`Deleted ${path.relative(repoRoot, appPath)}`);
  }

  if (fs.existsSync(valuesPath)) {
    fs.unlinkSync(valuesPath);
    console.log(`Deleted ${path.relative(repoRoot, valuesPath)}`);
  }

  if (fs.existsSync(envDir) && fs.readdirSync(envDir).length === 0) {
    fs.rmSync(envDir, { recursive: true, force: true });
    console.log(`Deleted ${path.relative(repoRoot, envDir)}`);
  }

  process.exit(0);
}

if (action !== 'create') {
  console.error(`Unknown action "${action}". Use create or delete.`);
  process.exit(1);
}

if (!fs.existsSync(developValuesPath)) {
  console.error(`Missing ${path.relative(repoRoot, developValuesPath)}.`);
  process.exit(1);
}

fs.mkdirSync(appsDir, { recursive: true });
fs.mkdirSync(envDir, { recursive: true });

const developValues = fs.readFileSync(developValuesPath, 'utf8');
const featureValues = replaceIngressHosts(replaceNamespace(developValues, namespace), namespace);

fs.writeFileSync(valuesPath, featureValues, 'utf8');
console.log(`Wrote ${path.relative(repoRoot, valuesPath)}`);

const manifest = `apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${appName}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/h4rkon/argotest.git
    targetRevision: develop
    path: helm/argotest-environment
    helm:
      valueFiles:
        - ../../environments/${namespace}/values.yaml
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
