/**
 * render: turn the collected data into markdown. Stage 3 of 3 (collect -> map -> render).
 *
 * Rendering only — no audit scan, no attribution. Reads scripts/data (usage-by-session.json from collect.mts,
 * session-projects.json from map.mts), joins on sessionId, and writes three views to scripts/reports:
 *   usage-by-project.md    — month -> days -> per-model -> per-project breakdown -> subtotal, then grand totals.
 *   daily-matrix.md        — day x project cost matrix, contiguous days, biggest project first.
 *   unknown-sessions.md    — sessions with no named project, with their cwd/source so they can be tracked down.
 *
 * Run:  npx tsx render.mts   (or: bun render.mts)   — fast; rerun after a hand-edit to session-projects.json
 * or the REPO_PROJECT table in map.mts, without re-collecting.
 *
 * Projects totalling <= $15 are folded into "other/misc" in the two cost views.
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { LocalDate, YearMonth, ZoneId } from "@js-joda/core";
import "@js-joda/timezone";

type Agg = { input: number; cacheWrite: number; cacheRead: number; output: number; cost: number; costInput: number; costCacheWrite: number; costCacheRead: number; costOutput: number };
type Usage = { generatedAt: string; tz: string; files: number; records: number; sessions: Record<string, Record<string, Record<string, Agg>>> };
type MapEntry = { cwd: string; source: string; project: string };
type MapFile = { generatedAt: string; sessions: Record<string, MapEntry> };

const DATA = join(dirname(fileURLToPath(import.meta.url)), "data");
const usage: Usage = JSON.parse(readFileSync(join(DATA, "usage-by-session.json"), "utf8"));
const projects: MapFile = JSON.parse(readFileSync(join(DATA, "session-projects.json"), "utf8"));

const TZ = usage.tz;
const today = LocalDate.now(ZoneId.of(TZ));
const MISC_THRESHOLD = 15;
const MISC = "other/misc";

const blank = (): Agg => ({ input: 0, cacheWrite: 0, cacheRead: 0, output: 0, cost: 0, costInput: 0, costCacheWrite: 0, costCacheRead: 0, costOutput: 0 });
const add = (t: Agg, s: Agg): Agg => {
  t.input += s.input;
  t.cacheWrite += s.cacheWrite;
  t.cacheRead += s.cacheRead;
  t.output += s.output;
  t.cost += s.cost;
  t.costInput += s.costInput;
  t.costCacheWrite += s.costCacheWrite;
  t.costCacheRead += s.costCacheRead;
  t.costOutput += s.costOutput;
  return t;
};
const bump = (m: Map<string, Agg>, k: string): Agg => {
  let a = m.get(k);
  if (!a) m.set(k, (a = blank()));
  return a;
};
const bump2 = (m: Map<string, Map<string, Agg>>, k1: string, k2: string): Agg => {
  let inner = m.get(k1);
  if (!inner) m.set(k1, (inner = new Map()));
  return bump(inner, k2);
};

// --- join: roll per-session day x model up against the project map ---------

const byDay = new Map<string, Agg>();
const byMonth = new Map<string, Agg>();
const byModel = new Map<string, Agg>();
const byMonthModel = new Map<string, Map<string, Agg>>();
const byMonthProject = new Map<string, Map<string, Agg>>();
const byProject = new Map<string, Agg>();
const byDayProject = new Map<string, Map<string, Agg>>();

for (const [sessionId, days] of Object.entries(usage.sessions)) {
  const project = projects.sessions[sessionId]?.project ?? "unknown";
  for (const [day, models] of Object.entries(days)) {
    const month = day.slice(0, 7);
    for (const [model, a] of Object.entries(models)) {
      add(bump(byDay, day), a);
      add(bump(byMonth, month), a);
      add(bump(byModel, model), a);
      add(bump2(byMonthModel, month, model), a);
      add(bump2(byMonthProject, month, project), a);
      add(bump2(byDayProject, day, project), a);
      add(bump(byProject, project), a);
    }
  }
}

// --- fold projects totalling <= $15 into "other/misc" ----------------------

const small = new Set([...byProject].filter(([, a]) => a.cost <= MISC_THRESHOLD).map(([p]) => p));
const foldInner = (m: Map<string, Map<string, Agg>>): void => {
  for (const inner of m.values()) {
    const misc = blank();
    let any = false;
    for (const p of small) {
      const a = inner.get(p);
      if (a) {
        add(misc, a);
        inner.delete(p);
        any = true;
      }
    }
    if (any) add(bump(inner, MISC), misc);
  }
};
if (small.size) {
  const misc = blank();
  for (const p of small) {
    add(misc, byProject.get(p)!);
    byProject.delete(p);
  }
  add(bump(byProject, MISC), misc);
  foldInner(byMonthProject);
  foldInner(byDayProject);
}

// --- shared table helpers --------------------------------------------------

const fmt = (n: number): string => (n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1000 ? `${Math.round(n / 1000)}k` : `${n}`);
const money = (n: number): string => (n > 0 ? `$${n.toFixed(2)}` : "");
const row = (label: string, a: Agg): string => `| ${label} | ${fmt(a.input)} | ${fmt(a.cacheWrite)} | ${fmt(a.cacheRead)} | ${fmt(a.output)} | $${a.cost.toFixed(2)} |`;
const boldRow = (label: string, a: Agg): string => `| **${label}** | **${fmt(a.input)}** | **${fmt(a.cacheWrite)}** | **${fmt(a.cacheRead)}** | **${fmt(a.output)}** | **$${a.cost.toFixed(2)}** |`;
const emptyRow = (label: string): string => `| ${label} | | | | | |`;
const spacer = "|  |  |  |  |  |  |";
const HEAD = "|  | Input | Cache write | Cache read | Output | Cost |";
const SEP = "|---|---|---|---|---|---|";
const byCost = (x: [string, Agg], y: [string, Agg]): number => y[1].cost - x[1].cost;

const months = [...byMonth.keys()].sort();
const grand = [...byMonth.values()].reduce((s, a) => add(s, a), blank());
const REPORTS = join(dirname(fileURLToPath(import.meta.url)), "reports");
mkdirSync(REPORTS, { recursive: true });
const write = (name: string, lines: string[]): string => {
  const p = join(REPORTS, name);
  writeFileSync(p, `${lines.join("\n")}\n`);
  return p;
};

// --- view 1: usage-by-project.md -------------------------------------------

const P: string[] = [];
P.push("# Claude usage by month and project (estimate)", "");
P.push(`All audit data, days in ${TZ} · ${usage.files} session files · ${usage.records.toLocaleString()} message records · rates from \`pricing.ts\`.`, "");
P.push("Estimate: per-message usage only (result-summary records excluded to avoid double-counting); cache writes split 5m/1h.", "");
P.push("Each month lists its days, then a per-model breakdown, then a per-project breakdown, then a subtotal; then the per-model and per-project grand totals.", "");
P.push(HEAD, SEP);
for (const month of months) {
  const ym = YearMonth.parse(month);
  const end = ym.atEndOfMonth().isAfter(today) ? today : ym.atEndOfMonth();
  for (let d = ym.atDay(1); !d.isAfter(end); d = d.plusDays(1)) {
    const a = byDay.get(d.toString());
    P.push(a ? row(d.toString(), a) : emptyRow(d.toString()));
  }
  P.push(spacer);
  for (const [model, a] of [...(byMonthModel.get(month) ?? new Map())].sort(byCost)) P.push(row(`${month} · ${model}`, a));
  P.push(spacer);
  for (const [project, a] of [...(byMonthProject.get(month) ?? new Map())].sort(byCost)) P.push(row(`${month} · ${project}`, a));
  P.push(boldRow(`${month} subtotal`, byMonth.get(month)!));
  P.push(spacer);
}
for (const [model, a] of [...byModel].sort(byCost)) P.push(row(`all · ${model}`, a));
P.push(spacer);
for (const [project, a] of [...byProject].sort(byCost)) P.push(row(`all · ${project}`, a));
const totalTokens = grand.input + grand.cacheWrite + grand.cacheRead + grand.output;
const pct = (n: number): string => (totalTokens === 0 ? "0%" : `${((n / totalTokens) * 100).toFixed(1)}%`);
P.push("| **Grand Total** | **Input** | **Cache Write** | **Cache Read** | **Output** | **Total** |");
P.push(`| **Tokens** | ${fmt(grand.input)} | ${fmt(grand.cacheWrite)} | ${fmt(grand.cacheRead)} | ${fmt(grand.output)} | ${fmt(totalTokens)} |`);
P.push(`| **Cost** | $${grand.costInput.toFixed(2)} | $${grand.costCacheWrite.toFixed(2)} | $${grand.costCacheRead.toFixed(2)} | $${grand.costOutput.toFixed(2)} | $${grand.cost.toFixed(2)} |`);
P.push(`| **%** | ${pct(grand.input)} | ${pct(grand.cacheWrite)} | ${pct(grand.cacheRead)} | ${pct(grand.output)} | 100% |`, "");
const p1 = write("usage-by-project.md", P);

// --- view 2: daily-matrix.md -----------------------------------------------

const projTotal = new Map<string, number>();
for (const [p, a] of byProject) projTotal.set(p, a.cost);
const cols = [...projTotal.entries()].sort((a, b) => b[1] - a[1]).map(([p]) => p);
const present = [...byDayProject.keys()].sort();
const days: string[] = [];
if (present.length) for (let d = LocalDate.parse(present[0]); !d.isAfter(today); d = d.plusDays(1)) days.push(d.toString());

const Mx: string[] = [];
Mx.push("# Claude daily cost by project (estimate)", "");
Mx.push(`Days in ${TZ}. Rows are days, columns are projects (biggest first). Cells are cost; blank means no spend that day.`, "");
Mx.push(`| Day | ${cols.join(" | ")} | Total |`);
Mx.push(`|---|${cols.map(() => "---:").join("|")}|---:|`);
for (const day of days) {
  const byProj = byDayProject.get(day);
  const cells = cols.map((p) => money(byProj?.get(p)?.cost ?? 0));
  const dayTotal = byDay.get(day)?.cost ?? 0;
  Mx.push(`| ${day} | ${cells.join(" | ")} | $${dayTotal.toFixed(2)} |`);
}
Mx.push(`| **Total** | ${cols.map((p) => `**$${(projTotal.get(p) ?? 0).toFixed(2)}**`).join(" | ")} | **$${grand.cost.toFixed(2)}** |`, "");
const p2 = write("daily-matrix.md", Mx);

// --- view 3: unknown-sessions.md -------------------------------------------

type Row = { sessionId: string; cwd: string; source: string; firstDay: string; lastDay: string; cost: number };
const unknown: Row[] = [];
for (const [sessionId, days] of Object.entries(usage.sessions)) {
  const mapped = projects.sessions[sessionId];
  if (mapped && mapped.project !== "unknown") continue;
  const dayKeys = Object.keys(days).sort();
  let cost = 0;
  for (const models of Object.values(days)) for (const a of Object.values(models)) cost += a.cost;
  unknown.push({ sessionId, cwd: mapped?.cwd ?? "", source: mapped?.source ?? "", firstDay: dayKeys[0], lastDay: dayKeys[dayKeys.length - 1], cost });
}
unknown.sort((a, b) => b.cost - a.cost);
const unknownTotal = unknown.reduce((s, r) => s + r.cost, 0);

const U: string[] = [];
U.push("# Claude unknown-project sessions (estimate)", "");
U.push(`${unknown.length} sessions have no named project, costing $${unknownTotal.toFixed(2)} in total (days in ${TZ}).`, "");
U.push("Many have a known cwd (shown) that just isn't a repo, or a repo with no REPO_PROJECT row yet. Highest cost first.", "");
U.push("| Session | cwd | Source | First | Last | Cost |", "|---|---|---|---|---|---:|");
for (const r of unknown) U.push(`| ${r.sessionId} | ${r.cwd || "—"} | ${r.source || "—"} | ${r.firstDay} | ${r.lastDay} | $${r.cost.toFixed(2)} |`);
U.push(`| **Total** | | | | | **$${unknownTotal.toFixed(2)}** |`, "");
const p3 = write("unknown-sessions.md", U);

// --- view 4: known-sessions.md ---------------------------------------------
// Every attributed session, grouped by project, with how it was attributed (source + cwd) so the mapping
// can be audited session by session. Uses the raw map project (before the <=$15 "other/misc" fold).

type Known = { sessionId: string; source: string; cwd: string; cost: number };
const byProjectSessions = new Map<string, Known[]>();
for (const [sessionId, days] of Object.entries(usage.sessions)) {
  const mapped = projects.sessions[sessionId];
  const project = mapped?.project ?? "unknown";
  let cost = 0;
  for (const models of Object.values(days)) for (const a of Object.values(models)) cost += a.cost;
  const arr = byProjectSessions.get(project) ?? [];
  byProjectSessions.set(project, arr);
  arr.push({ sessionId, source: mapped?.source ?? "—", cwd: mapped?.cwd ?? "—", cost });
}
const projectCost = (arr: Known[]): number => arr.reduce((s, k) => s + k.cost, 0);
const orderedProjects = [...byProjectSessions.entries()].sort((a, b) => projectCost(b[1]) - projectCost(a[1]));

const K: string[] = [];
K.push("# Claude known sessions by project (estimate)", "");
K.push(`Every session with a resolved cwd, grouped by project, with how it was attributed. Days in ${TZ}.`, "");
K.push("Source: testament (operator's own testament path) · dispatch (fleet dispatch-worktree repoPath) · db · history.", "");
for (const [project, arr] of orderedProjects) {
  arr.sort((a, b) => b.cost - a.cost);
  K.push("", `## ${project} — $${projectCost(arr).toFixed(2)} · ${arr.length} sessions`, "");
  K.push("| Session | Source | cwd | Cost |", "|---|---|---|---:|");
  for (const k of arr) K.push(`| ${k.sessionId} | ${k.source} | ${k.cwd} | $${k.cost.toFixed(2)} |`);
}
K.push("");
const p4 = write("known-sessions.md", K);

console.log(`wrote:\n  ${p1}\n  ${p2}\n  ${p3}\n  ${p4}`);
console.log(`${months.length} months, ${byProject.size} project columns, ${unknown.length} unknown ($${unknownTotal.toFixed(2)}), total $${grand.cost.toFixed(2)}`);
