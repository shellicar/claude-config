/**
 * collect: scan the audit logs into per-session usage. Stage 1 of 3 (collect -> map -> render).
 *
 * This stage knows NOTHING about cwd or project; it only reads usage and keys it by sessionId (the audit
 * filename). Attribution is map.mts, a separate stage, so changing how sessions map to projects never forces
 * a re-scan of the audit logs. render.mts joins this with map.mts's output.
 *
 * Run:  npx tsx collect.mts   (or: bun collect.mts)   — the slow step; rerun only when you want fresh usage.
 *
 * Per session it stores a day x model breakdown — enough for render.mts to rebuild every rollup (day, month,
 * model, month x model) plus the project breakdown. Rates from pricing.ts; a new version of a known model
 * family falls back to that family's current rate (warned), and an unrecognised model is priced $0.
 */
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Instant, ZoneId } from "@js-joda/core";
import "@js-joda/timezone";

const M = 1_000_000;

type Rates = { input: number; cw5: number; cw1: number; read: number; output: number };

// per-million-token rates from pricing.ts, one constant per tier so a rate is never repeated
const OPUS_HI: Rates = { input: 15, cw5: 18.75, cw1: 30, read: 1.5, output: 75 };
const OPUS: Rates = { input: 5, cw5: 6.25, cw1: 10, read: 0.5, output: 25 };
const SONNET: Rates = { input: 3, cw5: 3.75, cw1: 6, read: 0.3, output: 15 };
const HAIKU_4_5: Rates = { input: 1, cw5: 1.25, cw1: 2, read: 0.1, output: 5 };
const HAIKU_3_5: Rates = { input: 0.8, cw5: 1, cw1: 1.6, read: 0.08, output: 4 };
const HAIKU_3: Rates = { input: 0.25, cw5: 0.3, cw1: 0.5, read: 0.03, output: 1.25 };
const FABLE: Rates = { input: 10, cw5: 12.5, cw1: 20, read: 1, output: 50 };

const PRICING: Record<string, Rates> = {
  "claude-fable-5": FABLE,
  "claude-opus-4-8": OPUS,
  "claude-opus-4-7": OPUS,
  "claude-opus-4-6": OPUS,
  "claude-opus-4-5": OPUS,
  "claude-opus-4-1": OPUS_HI,
  "claude-opus-4": OPUS_HI,
  "claude-sonnet-4-6": SONNET,
  "claude-sonnet-4-5": SONNET,
  "claude-sonnet-4": SONNET,
  "claude-sonnet-3-7": SONNET,
  "claude-haiku-4-5": HAIKU_4_5,
  "claude-haiku-3-5": HAIKU_3_5,
  "claude-opus-3": OPUS_HI,
  "claude-haiku-3": HAIKU_3,
};

// Family fallback: a new model version inherits its family's current-generation rates until it gets its own
// row above (e.g. claude-sonnet-5 -> the sonnet rate). Estimate only, warned at the end so it stays visible;
// add an explicit PRICING row once the real rate is known. An unrecognised family is priced $0, never dropped.
const FAMILY: Record<string, Rates> = {
  "claude-fable": FABLE,
  "claude-opus": OPUS,
  "claude-sonnet": SONNET,
  "claude-haiku": HAIKU_4_5,
};
const ZERO: Rates = { input: 0, cw5: 0, cw1: 0, read: 0, output: 0 };
const estimated = new Map<string, number>();
const unpriced = new Map<string, number>();

const ratesFor = (model: string): Rates => {
  const exact = PRICING[model] ?? PRICING[model.replace(/-\d{8}$/, "")];
  if (exact) return exact;
  const fam = /^claude-(fable|opus|sonnet|haiku)/.exec(model)?.[0];
  if (fam && FAMILY[fam]) {
    estimated.set(model, (estimated.get(model) ?? 0) + 1);
    return FAMILY[fam];
  }
  unpriced.set(model, (unpriced.get(model) ?? 0) + 1);
  return ZERO;
};

const TZ = "Australia/Melbourne";
const ZONE = ZoneId.of(TZ);
const melbDay = (iso: string): string => Instant.parse(iso).atZone(ZONE).toLocalDate().toString();

type Agg = { input: number; cacheWrite: number; cacheRead: number; output: number; cost: number; costInput: number; costCacheWrite: number; costCacheRead: number; costOutput: number };
const blank = (): Agg => ({ input: 0, cacheWrite: 0, cacheRead: 0, output: 0, cost: 0, costInput: 0, costCacheWrite: 0, costCacheRead: 0, costOutput: 0 });
const add = (target: Agg, src: Agg): Agg => {
  target.input += src.input;
  target.cacheWrite += src.cacheWrite;
  target.cacheRead += src.cacheRead;
  target.output += src.output;
  target.cost += src.cost;
  target.costInput += src.costInput;
  target.costCacheWrite += src.costCacheWrite;
  target.costCacheRead += src.costCacheRead;
  target.costOutput += src.costOutput;
  return target;
};

const AUDIT = join(homedir(), ".claude", "audit");
const files = readdirSync(AUDIT)
  .filter((f) => f.endsWith(".jsonl"))
  .map((f) => join(AUDIT, f));

// sessionId -> day -> model -> Agg
const sessions: Record<string, Record<string, Record<string, Agg>>> = {};
let records = 0;

for (const file of files) {
  const sessionId = basename(file, ".jsonl");
  const days: Record<string, Record<string, Agg>> = {};
  let sessRecords = 0;

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
    let day: string;
    try {
      day = melbDay(timestamp);
    } catch {
      continue;
    }
    const r = ratesFor(model);

    const inp = usage.input_tokens ?? 0;
    const out = usage.output_tokens ?? 0;
    const cr = usage.cache_read_input_tokens ?? 0;
    const cc = usage.cache_creation ?? {};
    const cw5 = cc.ephemeral_5m_input_tokens ?? usage.cache_creation_input_tokens ?? 0;
    const cw1 = cc.ephemeral_1h_input_tokens ?? 0;
    const costInput = (inp * r.input) / M;
    const costCacheWrite = (cw5 * r.cw5 + cw1 * r.cw1) / M;
    const costCacheRead = (cr * r.read) / M;
    const costOutput = (out * r.output) / M;
    const cost = costInput + costCacheWrite + costCacheRead + costOutput;

    const one: Agg = { input: inp, cacheWrite: cw5 + cw1, cacheRead: cr, output: out, cost, costInput, costCacheWrite, costCacheRead, costOutput };
    const models = days[day] ?? (days[day] = {});
    add((models[model] ??= blank()), one);
    sessRecords++;
    records++;
  }

  if (sessRecords === 0) continue;
  sessions[sessionId] = days;
}

const out = {
  generatedAt: Instant.now().toString(),
  tz: TZ,
  files: files.length,
  records,
  sessions,
};

const DATA = join(dirname(fileURLToPath(import.meta.url)), "data");
mkdirSync(DATA, { recursive: true });
const outPath = join(DATA, "usage-by-session.json");
writeFileSync(outPath, `${JSON.stringify(out, null, 2)}\n`);

console.log(`wrote ${outPath}`);
console.log(`${files.length} files, ${records.toLocaleString()} records, ${Object.keys(sessions).length} sessions with usage`);
if (estimated.size) {
  const n = [...estimated.values()].reduce((a, b) => a + b, 0);
  console.warn(`estimated ${n} records on ${estimated.size} model(s) via family fallback, add a PRICING row: ${[...estimated.keys()].sort().join(", ")}`);
}
if (unpriced.size) {
  const n = [...unpriced.values()].reduce((a, b) => a + b, 0);
  console.warn(`priced $0, unrecognised model family: ${n} records on ${[...unpriced.keys()].sort().join(", ")}`);
}
