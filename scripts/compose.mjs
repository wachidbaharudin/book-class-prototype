// Thin wrapper that picks whichever Docker Compose CLI is installed
// (`docker compose` plugin or legacy `docker-compose`) and forwards every
// argument, so package scripts stay portable across machines.
import { spawnSync } from 'node:child_process';

const args = process.argv.slice(2);

function probe(cmd, base) {
  const result = spawnSync(cmd, [...base, 'version'], { stdio: 'ignore' });
  return !result.error && result.status === 0;
}

const [cmd, base] = probe('docker', ['compose']) ? ['docker', ['compose']] : ['docker-compose', []];

const result = spawnSync(cmd, [...base, ...args], { stdio: 'inherit' });
process.exit(result.status ?? 1);
