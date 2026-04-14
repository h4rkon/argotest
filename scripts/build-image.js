const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const serviceName = process.argv[2];

if (!serviceName) {
  console.error('Usage: node scripts/build-image.js <serviceName>');
  process.exit(1);
}

const repoRoot = path.resolve(__dirname, '..');
const serviceDir = path.join(repoRoot, 'services', serviceName);
const packageJsonPath = path.join(serviceDir, 'package.json');

if (!fs.existsSync(packageJsonPath)) {
  console.error(`Unknown service: ${serviceName}`);
  process.exit(1);
}

const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
const version = packageJson.version;
const imageName = process.env.IMAGE_NAME || serviceName.toLowerCase();

console.log(`Building ${imageName}:${version}`);

execFileSync(
  'docker',
  [
    'build',
    '-t',
    `${imageName}:${version}`,
    '-t',
    `${imageName}:latest`,
    serviceDir,
  ],
  { stdio: 'inherit' }
);
