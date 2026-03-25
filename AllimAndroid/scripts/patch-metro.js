#!/usr/bin/env node
/**
 * Patches @react-native/community-cli-plugin to fix:
 *   "Cannot read properties of undefined (reading 'handle')"
 *
 * Root cause: indexPageMiddleware resolves to undefined in some CLI versions
 * and gets passed directly into Metro's unstable_extraMiddleware array.
 * Metro then calls connect's app.use(undefined), which crashes.
 *
 * Fix: filter falsy values out of unstable_extraMiddleware before passing
 * to Metro, so undefined entries are silently dropped.
 *
 * Upstream PR: https://github.com/facebook/react-native/pull/49847
 */

const fs = require('fs');
const path = require('path');

const target = path.join(
  __dirname,
  '..',
  'node_modules',
  '@react-native',
  'community-cli-plugin',
  'dist',
  'commands',
  'start',
  'runServer.js',
);

if (!fs.existsSync(target)) {
  console.log('[patch-metro] runServer.js not found — skipping patch.');
  process.exit(0);
}

let src = fs.readFileSync(target, 'utf8');

if (src.includes('.filter(Boolean)')) {
  console.log('[patch-metro] Already patched — nothing to do.');
  process.exit(0);
}

const original = /unstable_extraMiddleware:\s*\[([^\]]+)\]/;
if (!original.test(src)) {
  console.warn('[patch-metro] Expected pattern not found — patch skipped. Metro may still fail.');
  process.exit(0);
}

src = src.replace(original, 'unstable_extraMiddleware: [$1].filter(Boolean)');

fs.writeFileSync(target, src);
console.log('[patch-metro] Patch applied — undefined middleware entries will be filtered out.');
