import fs from 'node:fs';

const source = fs.readFileSync(
  'C:/RTSQ TV/rtsq_tv/lib/core/supabase_client.dart',
  'utf8',
);
const url = source.match(/url\s*=\s*['"]([^'"]+)['"]/)?.[1];
const key = source.match(/publishableKey\s*=\s*['"]([^'"]+)['"]/)?.[1];

for (const table of ['settings', 'contents', 'ticker', 'devices']) {
  const response = await fetch(`${url}/rest/v1/${table}?select=*&limit=1`, {
    headers: { apikey: key, Accept: 'application/json' },
  });
  const text = await response.text();
  console.log(
    `${table}: ${response.status} ${text.slice(0, 120).replace(/\s+/g, ' ')}`,
  );
}

const auth = await fetch(`${url}/auth/v1/settings`, {
  headers: { apikey: key, Accept: 'application/json' },
});
const authBody = await auth.json();
console.log(`auth settings: ${auth.status} ${JSON.stringify(authBody)}`);
