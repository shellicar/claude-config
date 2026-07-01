/**
 * Estimate Claude usage cost from the audit logs, across all data, grouped by month, by day and model.
 *
 * Run:  npx tsx usage-report.ts   (or: bun usage-report.ts, or node --experimental-strip-types usage-report.ts)
 *
 * Rates copied from claude-cli/packages/claude-sdk/src/private/pricing.ts — keep in sync;
 * an unknown model is priced at $0 rather than guessed.
 *
 * Estimate, by design:
 * - reads every audit file; records in an older format that lack model/usage/timestamp are skipped
 * - counts per-message usage records (model set); skips `result` summaries (model: null) to avoid double-counting
 * - days are grouped in Australia/Melbourne (local), not UTC
 * - cache writes are split 5m/1h and priced at their separate rates
 * Per-message input grows with context each turn; summing it is correct — that is how the API bills.
 */
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Instant, LocalDate, YearMonth, ZoneId } from "@js-joda/core";
import "@js-joda/timezone";

const M = 1_000_000;

type Rates = { input: number; cw5: number; cw1: number; read: number; output: number };

// per-million-token rates from pricing.ts
const PRICING: Record<string, Rates> = {
  "claude-fable-5": { input: 10, cw5: 12.5, cw1: 20, read: 1, output: 50 },
  "claude-opus-4-8": { input: 5, cw5: 6.25, cw1: 10, read: 0.5, output: 25 },
  "claude-opus-4-7": { input: 5, cw5: 6.25, cw1: 10, read: 0.5, output: 25 },
  "claude-opus-4-6": { input: 5, cw5: 6.25, cw1: 10, read: 0.5, output: 25 },
  "claude-opus-4-5": { input: 5, cw5: 6.25, cw1: 10, read: 0.5, output: 25 },
  "claude-opus-4-1": { input: 15, cw5: 18.75, cw1: 30, read: 1.5, output: 75 },
  "claude-opus-4": { input: 15, cw5: 18.75, cw1: 30, read: 1.5, output: 75 },
  "claude-sonnet-4-6": { input: 3, cw5: 3.75, cw1: 6, read: 0.3, output: 15 },
  "claude-sonnet-4-5": { input: 3, cw5: 3.75, cw1: 6, read: 0.3, output: 15 },
  "claude-sonnet-4": { input: 3, cw5: 3.75, cw1: 6, read: 0.3, output: 15 },
  "claude-sonnet-3-7": { input: 3, cw5: 3.75, cw1: 6, read: 0.3, output: 15 },
  "claude-haiku-4-5": { input: 1, cw5: 1.25, cw1: 2, read: 0.1, output: 5 },
  "claude-haiku-3-5": { input: 0.8, cw5: 1, cw1: 1.6, read: 0.08, output: 4 },
  "claude-opus-3": { input: 15, cw5: 18.75, cw1: 30, read: 1.5, output: 75 },
  "claude-haiku-3": { input: 0.25, cw5: 0.3, cw1: 0.5, read: 0.03, output: 1.25 },
};

const ratesFor = (model: string): Rates | undefined => PRICING[model] ?? PRICING[model.replace(/-\d{8}$/, "")];

const TZ = "Australia/Melbourne";
const ZONE = ZoneId.of(TZ);
const today = LocalDate.now(ZONE);
const melbDay = (iso: string): LocalDate => Instant.parse(iso).atZone(ZONE).toLocalDate(); // local calendar day

type Agg = { input: number; cacheWrite: number; cacheRead: number; output: number; cost: number };
const blank = (): Agg => ({ input: 0, cacheWrite: 0, cacheRead: 0, output: 0, cost: 0 });
const add = (target: Agg, src: Agg): Agg => {
  target.input += src.input;
  target.cacheWrite += src.cacheWrite;
  target.cacheRead += src.cacheRead;
  target.output += src.output;
  target.cost += src.cost;
  return target;
};
const bump = (map: Map<string, Agg>, k: string): Agg => {
  let a = map.get(k);
  if (!a) {
    a = blank();
    map.set(k, a);
  }
  return a;
};

const AUDIT = join(homedir(), ".claude", "audit");
const files = readdirSync(AUDIT)
  .filter((f) => f.endsWith(".jsonl"))
  .map((f) => join(AUDIT, f));

const byDay = new Map<string, Agg>(); // key: LocalDate YYYY-MM-DD
const byMonth = new Map<string, Agg>(); // key: YearMonth YYYY-MM
const byModel = new Map<string, Agg>(); // key: model, across all data
const byMonthModel = new Map<string, Map<string, Agg>>(); // YYYY-MM -> model -> Agg
let records = 0;

for (const file of files) {
  for (const line of readFileSync(file, "utf8").split("\n")) {
    if (!line) continue;
    let rec: any;
    try {
      rec = JSON.parse(line);
    } catch {
      continue;
    }
    const { model, usage, timestamp } = rec;
    if (!model || !usage || !timestamp) continue;
    let date: LocalDate;
    try {
      date = melbDay(timestamp);
    } catch {
      continue;
    }
    const r = ratesFor(model);
    if (!r) continue;

    const day = date.toString();
    const month = YearMonth.from(date).toString();

    const inp = usage.input_tokens ?? 0;
    const out = usage.output_tokens ?? 0;
    const cr = usage.cache_read_input_tokens ?? 0;
    const cc = usage.cache_creation ?? {};
    const cw5 = cc.ephemeral_5m_input_tokens ?? usage.cache_creation_input_tokens ?? 0;
    const cw1 = cc.ephemeral_1h_input_tokens ?? 0;
    const cost = (inp * r.input + cw5 * r.cw5 + cw1 * r.cw1 + cr * r.read + out * r.output) / M;

    const one: Agg = { input: inp, cacheWrite: cw5 + cw1, cacheRead: cr, output: out, cost };
    add(bump(byDay, day), one);
    add(bump(byMonth, month), one);
    add(bump(byModel, model), one);
    const mm = byMonthModel.get(month) ?? new Map<string, Agg>();
    byMonthModel.set(month, mm);
    add(bump(mm, model), one);
    records++;
  }
}

const fmt = (n: number): string => (n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1000 ? `${Math.round(n / 1000)}k` : `${n}`);
const row = (label: string, a: Agg): string => `| ${label} | ${fmt(a.input)} | ${fmt(a.cacheWrite)} | ${fmt(a.cacheRead)} | ${fmt(a.output)} | $${a.cost.toFixed(2)} |`;
const boldRow = (label: string, a: Agg): string => `| **${label}** | **${fmt(a.input)}** | **${fmt(a.cacheWrite)}** | **${fmt(a.cacheRead)}** | **${fmt(a.output)}** | **$${a.cost.toFixed(2)}** |`;
const emptyRow = (label: string): string => `| ${label} | | | | | |`;
const spacer = "|  |  |  |  |  |  |";
const HEAD = "|  | Input | Cache write | Cache read | Output | Cost |";
const SEP = "|---|---|---|---|---|---|";
const byCost = (x: [string, Agg], y: [string, Agg]): number => y[1].cost - x[1].cost;

const months = [...byMonth.keys()].sort();
const grand = [...byMonth.values()].reduce((s, a) => add(s, a), blank());

const L: string[] = [];
L.push("# Claude usage (estimate)", "");
L.push(`All audit data, days in ${TZ} · ${files.length} session files · ${records.toLocaleString()} message records · rates from \`pricing.ts\`.`, "");
L.push("Estimate: per-message usage only (result-summary records excluded to avoid double-counting); cache writes split 5m/1h.", "");
L.push("Rows are each month's days and per-model breakdown with a subtotal, then the per-model and overall grand totals.", "");

L.push(HEAD, SEP);
for (const month of months) {
  const ym = YearMonth.parse(month);
  const end = ym.atEndOfMonth().isAfter(today) ? today : ym.atEndOfMonth();
  for (let d = ym.atDay(1); !d.isAfter(end); d = d.plusDays(1)) {
    const a = byDay.get(d.toString());
    L.push(a ? row(d.toString(), a) : emptyRow(d.toString()));
  }
  L.push(spacer);
  for (const [model, a] of [...byMonthModel.get(month)!].sort(byCost)) L.push(row(`${month} · ${model}`, a));
  L.push(boldRow(`${month} subtotal`, byMonth.get(month)!));
  L.push(spacer);
}
for (const [model, a] of [...byModel].sort(byCost)) L.push(row(`all · ${model}`, a));
L.push(boldRow("Grand total", grand));
L.push("");

const outPath = join(AUDIT, "usage-by-month.md");
writeFileSync(outPath, `${L.join("\n")}\n`);

console.log(`wrote ${outPath}`);
console.log(`${files.length} files, ${records.toLocaleString()} records, ${months.length} months, total $${grand.cost.toFixed(2)}`);
for (const [model, a] of [...byModel].sort(byCost)) console.log(`  ${model.padEnd(22)} $${a.cost.toFixed(2)}`);
