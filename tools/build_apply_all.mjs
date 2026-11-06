import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const dir = 'C:/RTSQ TV/supabase/migrations';
const files = readdirSync(dir)
  .filter((name) => name.endsWith('.sql'))
  .sort();

const parts = [
  '-- RTSQ TV — gabungan migrasi 0001 sampai 0008',
  '-- Tempel seluruh isi berkas ini ke Supabase SQL Editor, lalu Run sekali.',
  '-- Dibuat otomatis dari supabase/migrations; jangan diedit manual.',
  '',
  'begin;',
  '',
];

for (const name of files) {
  parts.push(
    '-- ===========================================================================',
    `-- ${name}`,
    '-- ===========================================================================',
    '',
    readFileSync(join(dir, name), 'utf8').trimEnd(),
    '',
  );
}

parts.push('commit;', '');

writeFileSync('C:/RTSQ TV/supabase/apply_all.sql', parts.join('\n'), 'utf8');
console.log(`Ditulis apply_all.sql dari ${files.length} berkas.`);
