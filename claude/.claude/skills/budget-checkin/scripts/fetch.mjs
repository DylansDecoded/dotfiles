#!/usr/bin/env node
// Data-source layer ONLY — emits normalized budget JSON on stdout, no analysis.
// To swap sources (YNAB, etc.): add a loader returning [{name, group, budgeted, spent}]
// and wire it to a new "source" value. Everything downstream stays untouched.
import { readFileSync, existsSync, mkdirSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, dirname } from 'node:path';

const CONFIG_PATH =
  process.env.BUDGET_CHECKIN_CONFIG ??
  join(homedir(), '.config', 'budget-checkin', 'config.json');

function fail(code, message) {
  console.log(JSON.stringify({ error: code, message, config_path: CONFIG_PATH }, null, 2));
  process.exit(1);
}

if (!existsSync(CONFIG_PATH)) {
  fail('no_config', 'Config file not found. See the Setup section of the budget-checkin skill.');
}

let config;
try {
  config = JSON.parse(readFileSync(CONFIG_PATH, 'utf8'));
} catch (e) {
  fail('bad_config', `Could not parse config: ${e.message}`);
}

const now = new Date();
const month = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
const dayOfMonth = now.getDate();
const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();

function isPlaceholder(v) {
  return !v || /FILL_ME_IN|CHANGE_ME|YOUR_/i.test(String(v));
}

async function fromFixture(cfg) {
  if (!cfg?.path) fail('bad_fixture', 'source is "fixture" but fixture.path is not set.');
  if (!existsSync(cfg.path)) fail('bad_fixture', `Fixture file not found: ${cfg.path}`);
  const data = JSON.parse(readFileSync(cfg.path, 'utf8'));
  if (!Array.isArray(data.categories)) fail('bad_fixture', 'Fixture must contain a "categories" array.');
  return data.categories;
}

async function fromActual(cfg) {
  const password = process.env.ACTUAL_PASSWORD || cfg?.password;
  const missing = [];
  if (isPlaceholder(cfg?.serverURL)) missing.push('actual.serverURL');
  if (isPlaceholder(password)) missing.push('actual.password (or ACTUAL_PASSWORD env var)');
  if (isPlaceholder(cfg?.syncId)) missing.push('actual.syncId (Actual: Settings → Show advanced settings → Sync ID)');
  if (missing.length) {
    fail('not_configured', `Actual Budget connection incomplete. Fill in: ${missing.join(', ')}`);
  }

  let api;
  try {
    const mod = await import('@actual-app/api');
    api = mod.default ?? mod;
  } catch (e) {
    fail('missing_dependency', `@actual-app/api not installed. Run: npm install --prefix ${dirname(new URL(import.meta.url).pathname)} (${e.message})`);
  }

  const dataDir = join(dirname(CONFIG_PATH), 'cache');
  mkdirSync(dataDir, { recursive: true });

  try {
    await api.init({ dataDir, serverURL: cfg.serverURL, password });
    await api.downloadBudget(
      cfg.syncId,
      cfg.encryptionPassword ? { password: cfg.encryptionPassword } : undefined,
    );
    const budget = await api.getBudgetMonth(month);
    const toAmount = api.utils?.integerToAmount ?? ((n) => n / 100);
    const categories = [];
    for (const group of budget.categoryGroups ?? []) {
      if (group.is_income || group.hidden) continue;
      for (const cat of group.categories ?? []) {
        if (cat.hidden) continue;
        const budgeted = toAmount(cat.budgeted ?? 0);
        const spent = -toAmount(cat.spent ?? 0); // Actual reports spending as negative
        if (budgeted === 0 && spent === 0) continue;
        categories.push({ name: cat.name, group: group.name, budgeted, spent });
      }
    }
    return categories;
  } catch (e) {
    fail('actual_error', `Could not fetch from Actual server: ${e.message}`);
  } finally {
    try { await api.shutdown(); } catch { /* already failed; keep original error */ }
  }
}

const source = config.source ?? 'actual';
const loaders = { actual: () => fromActual(config.actual), fixture: () => fromFixture(config.fixture) };
if (!loaders[source]) fail('bad_config', `Unknown source "${source}". Expected one of: ${Object.keys(loaders).join(', ')}`);

const categories = await loaders[source]();

console.log(JSON.stringify({
  source,
  month,
  as_of: now.toISOString().slice(0, 10),
  day_of_month: dayOfMonth,
  days_in_month: daysInMonth,
  pct_month_elapsed: Math.round((dayOfMonth / daysInMonth) * 100),
  categories,
}, null, 2));
