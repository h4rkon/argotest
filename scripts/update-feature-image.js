const fs = require('fs');
const path = require('path');

const [branch, serviceName, imageTag] = process.argv.slice(2);

if (!branch || !serviceName || !imageTag) {
  console.error('Usage: node scripts/update-feature-image.js <branch> <service> <tag>');
  process.exit(1);
}

const jiraMatch = branch.match(/([A-Z]+-\d+)/);
if (!jiraMatch) {
  console.error(`Branch "${branch}" does not contain a Jira key like OAS-1234.`);
  process.exit(1);
}

const normalize = (value) =>
  value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

const namespace = normalize(branch);
const repoRoot = path.resolve(__dirname, '..');
const valuesPath = path.join(repoRoot, 'environments', namespace, 'values.yaml');

if (!fs.existsSync(valuesPath)) {
  console.error(`Feature values file not found: ${path.relative(repoRoot, valuesPath)}`);
  process.exit(1);
}

const values = fs.readFileSync(valuesPath, 'utf8');
const servicePattern = new RegExp(
  `(^  ${serviceName}:\\n(?:    .*\\n)*?    image:\\n(?:      .*\\n)*?      tag: ).*$`,
  'm'
);

if (!servicePattern.test(values)) {
  console.error(`Service "${serviceName}" not found in ${path.relative(repoRoot, valuesPath)}`);
  process.exit(1);
}

const updated = values.replace(servicePattern, `$1${imageTag}`);
fs.writeFileSync(valuesPath, updated, 'utf8');
console.log(`Updated ${serviceName} image tag in ${path.relative(repoRoot, valuesPath)} to ${imageTag}`);
