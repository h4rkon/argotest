const http = require('http');
const packageJson = require('../package.json');

const port = Number(process.env.PORT) || 3000;
const host = '0.0.0.0';

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/hello') {
    res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end(`hello world from serviceA v${packageJson.version}`);
    return;
  }

  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('not found');
});

server.listen(port, host, () => {
  console.log(`serviceA listening on ${host}:${port}`);
});
