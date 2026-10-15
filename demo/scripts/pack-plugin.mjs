/* eslint-disable no-console */
// Installs the plugin THIS checkout holds into the demo, the way npm would ship it. `cordova plugin add ..` would copy the
// parent folder, which contains the demo itself, so the plugin is packed first and only its files are installed.
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// `cordova plugin add <folder>` runs `npm install` in that folder, which would also install its devDependencies into the demo.
function dropDevelopmentFields(dir) {
  const manifestPath = join(dir, 'package.json');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  delete manifest.devDependencies;
  delete manifest.scripts;
  writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
}

const demo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const root = resolve(demo, '..');
const out = join(demo, '.plugin');
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const tarball = execFileSync('npm', ['pack', '--silent', '--pack-destination', out], { cwd: root, encoding: 'utf8' }).trim().split('\n').pop();
execFileSync('tar', ['-xzf', join(out, tarball), '-C', out, '--strip-components=1']);
rmSync(join(out, tarball));
dropDevelopmentFields(out);
const { id } = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')).cordova;
try {
  execFileSync('npx', ['cordova', 'plugin', 'rm', id, '--nosave'], { cwd: demo, stdio: 'ignore' });
} catch {
  // not installed yet
}
execFileSync('npx', ['cordova', 'plugin', 'add', out, '--nosave'], { cwd: demo, stdio: 'inherit' });
console.log(`installed ${id} from ${out}`);
