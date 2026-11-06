import fs from 'node:fs';
import path from 'node:path';

const dir = 'C:/RTSQ TV/supabase/migrations';
const files = fs
  .readdirSync(dir)
  .filter((name) => name.endsWith('.sql'))
  .sort();

function scan(source) {
  let i = 0;
  const n = source.length;
  const problems = [];

  const lineAt = (offset) => source.slice(0, offset).split('\n').length;

  while (i < n) {
    const c = source[i];

    if (c === '-' && source[i + 1] === '-') {
      const end = source.indexOf('\n', i);
      i = end === -1 ? n : end + 1;
      continue;
    }

    if (c === '/' && source[i + 1] === '*') {
      const end = source.indexOf('*/', i + 2);
      if (end === -1) {
        problems.push(`block comment tidak ditutup di baris ${lineAt(i)}`);
        break;
      }
      i = end + 2;
      continue;
    }

    if (c === "'") {
      const start = i;
      i++;
      let closed = false;
      while (i < n) {
        if (source[i] === "'") {
          if (source[i + 1] === "'") {
            i += 2;
            continue;
          }
          closed = true;
          i++;
          break;
        }
        if (source[i] === '\\' && source[i - 1] === 'E') {
          i += 2;
          continue;
        }
        i++;
      }
      if (!closed) {
        problems.push(`string tunggal tidak ditutup mulai baris ${lineAt(start)}`);
      }
      continue;
    }

    if (c === '$') {
      const match = source.slice(i).match(/^\$[A-Za-z_][A-Za-z0-9_]*\$|^\$\$/);
      if (match) {
        const tag = match[0];
        const start = i;
        const end = source.indexOf(tag, i + tag.length);
        if (end === -1) {
          problems.push(`dollar quote ${tag} tidak ditutup mulai baris ${lineAt(start)}`);
          break;
        }
        i = end + tag.length;
        continue;
      }
    }

    i++;
  }

  return problems;
}

for (const name of files) {
  const source = fs.readFileSync(path.join(dir, name), 'utf8');
  const problems = scan(source);
  const dollar = (source.match(/\$/g) || []).length;
  console.log(
    `${name}: ${problems.length ? problems.join('; ') : 'OK'} (tanda $: ${dollar}, baris: ${source.split('\n').length})`,
  );
}
