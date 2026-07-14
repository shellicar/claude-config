/**
 * map: attribute each session to a cwd, then to a project. Stage 2 of 3 (collect -> map -> render).
 *
 * Separate from collect.mts on purpose: cheap, independent of the audit logs, and the output is plain enough
 * to hand-edit. Correct a wrong entry (or the REPO_PROJECT table below) and rerun render.mts — no re-collection.
 * Each session gets a cwd (kept even when the project can't be named) and a project.
 *
 * A session is resolved to a repo, then the repo IS the project (via REPO_PROJECT). Repo is found from, in order:
 *   1. testament — the first tool_use touching a <repo-root>/.claude/testament path in the transcript.
 *      An operator only reads/writes its own testament at its repo root, so this is authoritative.
 *   2. dispatch  — the repoPath a scripts/dispatch-worktree.mjs execution was handed. This is how a fleet
 *      handler session names the repo it is coordinating (the worktree slug does not name it reliably —
 *      easyquote work happens in CarKiosk, apollo-v5 in Customer-Interactions).
 *   3. db        — ~/.claude/sessions.db sessions(conversation_id, cwd, created_at).
 *   4. history   — a .sdk-conversation-history file under any <cwd>/.claude (searched from home).
 * Transcript signals (1,2) win over recorded cwd (3,4) because they name the actual project, not a worktree.
 * A bare claude-fleet-eagers cwd with no dispatch is general fleet work ("eagers fleet"). Anything left is unmapped
 * and the renderer treats it as "unknown".
 */
import { execFileSync } from "node:child_process";
import { mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HOME = homedir();

// repo (path under repos/, worktree suffix stripped) -> project. Hand-maintained; add rows as projects appear.
const REPO_PROJECT: Record<string, string> = {
  "Eagers/appraisals/appraisals": "appraisals",
  "Eagers/Deal-Hub/Customer-Payments": "customer-payments",
  "Eagers/Deal-Hub/Customer-Interactions": "easypass",
  "Eagers/CarKiosk/CarKiosk": "easyquote",
  "Eagers/leads/LeadsAPI": "leads",
  "Eagers/Black Ops/KnowledgeSharing": "knowledge-sharing",
  "Eagers/Black Ops/mcp-calendar": "calendar-management",
  "Eagers/eashared/eagers.products.services": "products-api",
};

// Known project names (the fleet projects/ dir). Hand-maintained. A fleet worktree slug is matched against
// these by prefix, so claude-fleet-*--easypass-gbg-results resolves to "easypass".
const PROJECTS = ["appraisals", "calendar-management", "claude-pr-review", "customer-payments", "easypass", "easyquote", "knowledge-sharing", "leads", "products-api"];

// Absolute-path overrides, checked first. For cwds that aren't repos (or that you want pinned regardless).
// Longest prefix wins. Hand-maintained.
const PATH_PROJECT: [string, string][] = [
  [join(HOME, "claude-swe"), "benchmark"],
  [join(HOME, "dotfiles"), "other/misc"],
  [join(HOME, ".claude"), "other/misc"],
];

// Map a resolved cwd/repo path to a project label.
const projectOf = (cwd: string): string => {
  const hit = PATH_PROJECT.filter(([prefix]) => cwd === prefix || cwd.startsWith(`${prefix}/`)).sort((a, b) => b[0].length - a[0].length)[0];
  if (hit) return hit[1];

  const parts = cwd.split("/").filter(Boolean);
  const ri = parts.lastIndexOf("repos");
  if (ri === -1 || ri + 1 >= parts.length) return "unknown";
  const rest = parts.slice(ri + 1);

  // A fleet worktree at any location (~/repos/shellicar/... or a mis-cloned ~/repos/fleet/...). The slug names
  // the project; a bare fleet repo or an unrecognised slug is general fleet work.
  const fleet = rest.find((s) => s.startsWith("claude-fleet-"));
  if (fleet) {
    const dd = fleet.indexOf("--");
    if (dd === -1) return "eagers fleet";
    const slug = fleet.slice(dd + 2);
    return PROJECTS.find((p) => slug === p || slug.startsWith(`${p}-`)) ?? "eagers fleet";
  }

  // Non-fleet. Eagers is Azure DevOps: org/project/repo (3 levels). The repo is the 3rd segment, so match the
  // full 3-segment key and otherwise fall back to the repo name itself (never the 2-segment grouping folder).
  // A partial Eagers path with no repo segment is misc. GitHub is owner/repo (2 levels), where owner/repo is a
  // fine label (e.g. shellicar/skills).
  const clean = rest.map((s) => s.split("--")[0]);
  if (clean[0] === "Eagers") return REPO_PROJECT[clean.slice(0, 3).join("/")] ?? clean[2] ?? "other/misc";
  const key2 = clean.slice(0, 2).join("/");
  return REPO_PROJECT[key2] ?? key2;
};

const expand = (p: string): string => (p.startsWith("~") ? p.replace(/^~/, HOME) : p);

// --- recorded-cwd sources (db, history) ------------------------------------

type Source = "testament" | "dispatch" | "db" | "history";
const dbCwd = new Map<string, string>();
const historyCwd = new Map<string, string>();

// Walk from home so history files anywhere (~/repos, ~/dotfiles, ...) are found, not just under ~/repos.
// Skip the heavy/system trees and cap depth so it stays quick.
const WALK_SKIP = new Set(["node_modules", ".git", "dist", ".next", "coverage", "Library", ".Trash", ".cache", ".npm", ".pnpm-store", ".cargo", ".rustup", "go", "Applications", "Music", "Movies", "Pictures"]);
const MAX_DEPTH = 8;
const walkForHistory = (root: string, depth: number): void => {
  let entries: string[];
  try {
    entries = readdirSync(root);
  } catch {
    return;
  }
  for (const name of entries) {
    const full = join(root, name);
    let st: ReturnType<typeof statSync>;
    try {
      st = statSync(full);
    } catch {
      continue;
    }
    if (st.isDirectory()) {
      if (WALK_SKIP.has(name) || depth >= MAX_DEPTH) continue;
      walkForHistory(full, depth + 1);
      continue;
    }
    if (name !== ".sdk-conversation-history") continue;
    const cwd = dirname(dirname(full));
    for (const line of readFileSync(full, "utf8").split("\n")) {
      const id = line.trim();
      if (id) historyCwd.set(id, cwd);
    }
  }
};
walkForHistory(HOME, 0);

try {
  const json = execFileSync("sqlite3", [join(HOME, ".claude", "sessions.db"), "-json", "select conversation_id, cwd from sessions order by created_at asc"], { encoding: "utf8" });
  const rows: { conversation_id: string; cwd: string }[] = json.trim() ? JSON.parse(json) : [];
  for (const r of rows) dbCwd.set(r.conversation_id, r.cwd);
} catch (e) {
  console.warn(`sessions.db not read (${(e as Error).message}); continuing without it.`);
}

// --- transcript signals (testament, dispatch) ------------------------------

const REPO_PATH = /([~/][A-Za-z0-9._/-]*)\/\.claude\/testament/;
const REPO_PATH_DISPATCH = /repoPath"?\s*:\s*"?([~/][^"\\ ,}]+)/;

// Collect the string leaves of a tool_use input (JSON re-encoding would hide the payload behind escapes).
const leaves = (x: unknown, acc: string[]): void => {
  if (typeof x === "string") acc.push(x);
  else if (Array.isArray(x)) for (const v of x) leaves(v, acc);
  else if (x && typeof x === "object") for (const v of Object.values(x)) leaves(v, acc);
};

type Signals = { testament?: string; dispatch?: string };
const scanTranscript = (file: string): Signals => {
  let data: string;
  try {
    data = readFileSync(file, "utf8");
  } catch {
    return {};
  }
  if (!data.includes("testament") && !data.includes("dispatch-worktree")) return {};
  const out: Signals = {};
  for (const line of data.split("\n")) {
    if (!line) continue;
    let obj: unknown;
    try {
      obj = JSON.parse(line);
    } catch {
      continue;
    }
    const stack: unknown[] = [obj];
    while (stack.length) {
      const x = stack.pop();
      if (Array.isArray(x)) {
        stack.push(...x);
      } else if (x && typeof x === "object") {
        const o = x as Record<string, unknown>;
        if (o.type === "tool_use") {
          const acc: string[] = [];
          leaves(o.input, acc);
          const s = acc.join("\n");
          if (!out.testament && s.includes("/.claude/testament")) {
            const m = REPO_PATH.exec(s);
            if (m) out.testament = expand(m[1]);
          }
          if (!out.dispatch && s.includes("dispatch-worktree")) {
            const m = REPO_PATH_DISPATCH.exec(s);
            if (m) out.dispatch = expand(m[1]);
          }
        }
        stack.push(...Object.values(o));
      }
      if (out.testament && out.dispatch) return out;
    }
  }
  return out;
};

// --- resolve every session -------------------------------------------------

const CONV = join(HOME, ".claude", "conversations");
let convFiles: string[] = [];
try {
  convFiles = readdirSync(CONV).filter((f) => f.endsWith(".jsonl"));
} catch {
  // no conversations dir
}

const ids = new Set<string>([...dbCwd.keys(), ...historyCwd.keys(), ...convFiles.map((f) => f.slice(0, -".jsonl".length))]);

type Entry = { cwd: string; source: Source; project: string };
const map = new Map<string, Entry>();
for (const id of ids) {
  const sig = convFiles.includes(`${id}.jsonl`) ? scanTranscript(join(CONV, `${id}.jsonl`)) : {};
  let cwd: string | undefined;
  let source: Source | undefined;
  if (sig.testament) {
    cwd = sig.testament;
    source = "testament";
  } else if (sig.dispatch) {
    cwd = sig.dispatch;
    source = "dispatch";
  } else if (dbCwd.has(id)) {
    cwd = dbCwd.get(id);
    source = "db";
  } else if (historyCwd.has(id)) {
    cwd = historyCwd.get(id);
    source = "history";
  }
  if (!cwd || !source) continue;
  map.set(id, { cwd, source, project: projectOf(cwd) });
}

// --- write JSON ------------------------------------------------------------

const DATA = join(dirname(fileURLToPath(import.meta.url)), "data");
mkdirSync(DATA, { recursive: true });
const out = {
  generatedAt: new Date().toISOString(),
  repoProject: REPO_PROJECT,
  sessions: Object.fromEntries([...map].sort(([a], [b]) => a.localeCompare(b))),
};
const outPath = join(DATA, "session-projects.json");
writeFileSync(outPath, `${JSON.stringify(out, null, 2)}\n`);

const count = (s: Source): number => [...map.values()].filter((e) => e.source === s).length;
const projects = new Set([...map.values()].map((e) => e.project));
console.log(`wrote ${outPath}`);
console.log(`${map.size} sessions mapped (${count("testament")} testament, ${count("dispatch")} dispatch, ${count("db")} db, ${count("history")} history), ${projects.size} projects`);
