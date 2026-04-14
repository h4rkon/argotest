const fs = require('fs');
const path = require('path');

const serviceName = process.argv[2];
const branchName = process.argv[3];
const runNumber = process.argv[4];

if (!serviceName || !branchName || !runNumber) {
  console.error('Usage: node scripts/resolve-image-version.js <serviceName> <branchName> <runNumber>');
  process.exit(1);
}

const packageJsonPath = path.join(__dirname, '..', 'services', serviceName, 'package.json');

if (!fs.existsSync(packageJsonPath)) {
  console.error(`Unknown service: ${serviceName}`);
  process.exit(1);
}

const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
const baseVersion = packageJson.version;

const sanitizeBranch = (value) =>
  value
    .replace(/[^A-Za-z0-9._-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-{2,}/g, '-');

const ticketMatch = branchName.match(/([A-Z]+-\d+)/);
let versionTag;
let channelTag;

if (branchName === 'main') {
  versionTag = baseVersion;
  channelTag = 'latest';
} else if (branchName === 'develop') {
  versionTag = `${baseVersion}-develop.${runNumber}`;
  channelTag = 'develop-latest';
} else if (branchName.startsWith('feature/')) {
  const suffix = ticketMatch ? ticketMatch[1] : sanitizeBranch(branchName.slice('feature/'.length));
  versionTag = `${baseVersion}-${suffix}.${runNumber}`;
  channelTag = `${suffix}-latest`;
} else {
  const suffix = sanitizeBranch(branchName);
  versionTag = `${baseVersion}-${suffix}.${runNumber}`;
  channelTag = `${suffix}-latest`;
}

console.log(`version_tag=${versionTag}`);
console.log(`channel_tag=${channelTag}`);
