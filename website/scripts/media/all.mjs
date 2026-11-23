#!/usr/bin/env node
/** Capture website screenshots, then the walkthrough video, against a running preview. */
import { spawnSync } from 'node:child_process';
const tasks = [
  ['node', ['scripts/media/capture.mjs']],
  ['node', ['scripts/media/video.mjs']],
];
for (const [command, args] of tasks) {
  const result = spawnSync(command, args, { stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status || 1);
}
