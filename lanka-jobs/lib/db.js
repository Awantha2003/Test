import postgres from 'postgres';

const g = globalThis;

export function db() {
  if (!g.__ljsql) {
    g.__ljsql = postgres(process.env.DATABASE_URL, {
      ssl: 'require',
      prepare: false, // required for Supabase transaction pooler
      max: 3,
      idle_timeout: 20,
      connect_timeout: 15,
      connection: { search_path: 'lankajobs' },
    });
  }
  return g.__ljsql;
}

export async function getSetting(key, fallback = null) {
  const rows = await db()`select value from settings where key = ${key}`;
  return rows.length ? rows[0].value : fallback;
}

export async function setSetting(key, value) {
  await db()`insert into settings (key, value) values (${key}, ${value})
    on conflict (key) do update set value = excluded.value`;
}

export async function getSettings() {
  const rows = await db()`select key, value from settings`;
  return Object.fromEntries(rows.map((r) => [r.key, r.value]));
}
