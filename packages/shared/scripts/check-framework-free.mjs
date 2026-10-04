#!/usr/bin/env node
// Enforces the ENG-00 §4 rule: packages/shared must stay framework-free
// (plain TypeScript), so it can be consumed by both apps and CI scripts.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const packageRoot = fileURLToPath(new URL('..', import.meta.url));
const srcDir = join(packageRoot, 'src');

const FORBIDDEN = [
  { pattern: /(?:from|require\()\s*['"]@nestjs\//, label: '@nestjs/*' },
  { pattern: /(?:from|require\()\s*['"]next(?:\/|['"])/, label: 'next' },
  { pattern: /(?:from|require\()\s*['"]react(?:-dom)?(?:\/|['"])/, label: 'react / react-dom' },
];

function walk(dir) {
  return readdirSync(dir).flatMap((entry) => {
    const full = join(dir, entry);
    return statSync(full).isDirectory() ? walk(full) : [full];
  });
}

const violations = [];
for (const file of walk(srcDir)) {
  if (!file.endsWith('.ts')) continue;
  const lines = readFileSync(file, 'utf8').split('\n');
  lines.forEach((line, index) => {
    for (const { pattern, label } of FORBIDDEN) {
      if (pattern.test(line)) {
        violations.push(`${relative(packageRoot, file)}:${index + 1} imports ${label}`);
      }
    }
  });
}

if (violations.length > 0) {
  console.error('packages/shared must stay framework-free. Violations:');
  for (const violation of violations) console.error(`  - ${violation}`);
  process.exit(1);
}

console.log('packages/shared is framework-free ✓');
