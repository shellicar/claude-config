#!/usr/bin/env node

// Author: BananaBot9000 <bananabot9000@bananabot.dev>
import { readFileSync, writeFileSync, readdirSync, symlinkSync, readlinkSync, lstatSync, statSync, unlinkSync, existsSync, mkdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { homedir } from 'node:os';

const CLAUDE_DIR = join(homedir(), '.claude');
const CONFIG_PATH = join(CLAUDE_DIR, 'skills.json');
const ENV_PATH = join(CLAUDE_DIR, '.env');
const TARGET_DIR = join(CLAUDE_DIR, 'skills');

function loadSourceDir() {
  if (!existsSync(ENV_PATH)) {
    console.error(`Missing .env at ${ENV_PATH}`);
    console.error('Create it with: SKILLS_DIR=/path/to/your/skills/repo/skills');
    process.exit(1);
  }
  const match = readFileSync(ENV_PATH, 'utf8').match(/^SKILLS_DIR=(.+)$/m);
  if (!match) {
    console.error('SKILLS_DIR not set in .env');
    process.exit(1);
  }
  const dir = resolve(match[1].trim());
  if (!existsSync(dir)) {
    console.error(`Source directory not found: ${dir}`);
    process.exit(1);
  }
  return dir;
}

function loadConfig() {
  if (!existsSync(CONFIG_PATH)) return { skills: {} };
  return JSON.parse(readFileSync(CONFIG_PATH, 'utf8'));
}

function saveConfig(config) {
  const sorted = Object.keys(config.skills).sort().reduce((o, k) => { o[k] = config.skills[k]; return o; }, {});
  config.skills = sorted;
  writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2) + '\n');
}

function discoverSkills(srcDir) {
  const entries = readdirSync(srcDir, { withFileTypes: true }).filter(d => d.isDirectory());
  const valid = [];
  const invalid = [];

  for (const entry of entries) {
    const skillFile = join(srcDir, entry.name, 'SKILL.md');
    const stat = existsSync(skillFile) && statSync(skillFile);
    if (stat && stat.isFile() && stat.size > 0) {
      valid.push(entry.name);
    } else {
      invalid.push(entry.name);
    }
  }

  if (invalid.length > 0) {
    console.warn(`  Skipping ${invalid.length} invalid (missing/empty SKILL.md): ${invalid.join(', ')}`);
  }
 return valid;
}

function resolveActions(srcDir, skills, config) {
  mkdirSync(TARGET_DIR, { recursive: true });

  // Build desired state: enabled skills -> source path
  const desired = new Map();
  for (const skill of skills) {
    if (config.skills[skill] === true) {
      desired.set(skill, join(srcDir, skill));
    }
  }

  const toRemove = [];
  const toKeep = [];
  const toCreate = [];

  // Check existing symlinks against desired state
  for (const entry of readdirSync(TARGET_DIR)) {
    const fullPath = join(TARGET_DIR, entry);
    if (!lstatSync(fullPath).isSymbolicLink()) continue;

    const currentTarget = readlinkSync(fullPath);
    const expectedTarget = desired.get(entry);

    if (expectedTarget && resolve(currentTarget) === resolve(expectedTarget)) {
      toKeep.push(entry);
      desired.delete(entry);
    } else {
      toRemove.push(entry);
    }
  }

  // Remaining in desired = need to be created
  for (const [skill, src] of desired) {
    toCreate.push({ skill, src });
  }

  const skipped = skills.length - toKeep.length - toCreate.length;
  return { toRemove, toKeep, toCreate, skipped };
}

function executeActions({ toRemove, toCreate }) {
  for (const entry of toRemove) {
    const fullPath = join(TARGET_DIR, entry);
    unlinkSync(fullPath);
    console.log(`  - unlinked: ${entry}`);
  }

  for (const { skill, src } of toCreate) {
    symlinkSync(src, join(TARGET_DIR, skill));
    console.log(`  + linked:   ${skill}`);
  }
}

function main() {
  const srcDir = loadSourceDir();
  const config = loadConfig();
  config.skills ??= {};

  // 1. Discover valid skills from source
  const skills = discoverSkills(srcDir);

  // 2. Register new skills as disabled, save config if changed
  let updated = false;
  for (const skill of skills) {
    if (!(skill in config.skills)) {
      config.skills[skill] = false;
      updated = true;
      console.log(`  New skill discovered: ${skill} (disabled by default)`);
    }
  }
  if (updated) {
  saveConfig(config);
    console.log(`  Config updated: ${CONFIG_PATH}`);
  }

  // 3. Resolve what needs to change, then execute
  const actions = resolveActions(srcDir, skills, config);
  executeActions(actions);

  console.log(`\nSync complete:`);
  console.log(`  ${actions.toKeep.length} unchanged`);
  console.log(`  ${actions.toCreate.length} linked`);
  console.log(`  ${actions.toRemove.length} removed`);
  console.log(`  ${actions.skipped} disabled`);
}

main();
