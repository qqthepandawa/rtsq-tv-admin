import fs from 'node:fs';

const source = fs.readFileSync(
  'C:/RTSQ TV/rtsq_tv/lib/core/supabase_client.dart',
  'utf8',
);
const url = source.match(/url\s*=\s*['"]([^'"]+)['"]/)?.[1];
const key = source.match(/publishableKey\s*=\s*['"]([^'"]+)['"]/)?.[1];

const response = await fetch(`${url}/auth/v1/signup`, {
  method: 'POST',
  headers: {
    apikey: key,
    'Content-Type': 'application/json',
  },
  body: '{}',
});

const body = await response.json();
const summary = {
  status: response.status,
  id: body.user?.id,
  is_anonymous: body.user?.is_anonymous,
  error: body.error_code ?? body.msg ?? body.message,
};
console.log(JSON.stringify(summary, null, 2));
