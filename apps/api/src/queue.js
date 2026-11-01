import { randomUUID } from 'node:crypto';
import { mkdirSync, readdirSync, readFileSync, renameSync, unlinkSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// Antrean file FIFO untuk VPS mini (tanpa Redis): <dir>/pending/<id>.json.
// Gagal 3x -> <dir>/failed/<id>.json. Satu instance saja.
export const MAX_ATTEMPTS = 3;

let _seq = 0;

export function createFileQueue(dir) {
  const pending = join(dir, 'pending');
  const failed = join(dir, 'failed');
  mkdirSync(pending, { recursive: true });
  mkdirSync(failed, { recursive: true });

  return {
    dir,
    enqueue: ({ url }) => {
      const id = `job_${randomUUID().replaceAll('-', '').slice(0, 12)}`;
      const file = `${Date.now()}-${String(_seq++).padStart(6, '0')}_${id}.json`;
      writeFileSync(
        join(pending, file),
        JSON.stringify({ id, url, attempts: 0 }),
      );
      return { id };
    },
    // Ambil job tertua (atau null). File dipindah agar tak diproses ganda.
    claim: () => {
      const files = readdirSync(pending)
        .filter((f) => f.endsWith('.json') && !f.startsWith('.'))
        .sort();
      if (!files.length) return null;
      const path = join(pending, files[0]);
      const job = JSON.parse(readFileSync(path, 'utf8'));
      renameSync(path, join(pending, `.active_${files[0]}`));
      return { ...job, _active: `.active_${files[0]}` };
    },
    release: (job) => {
      renameSync(
        join(pending, job._active),
        join(pending, `${job.id}.json`),
      );
    },
    fail: (job, error) => {
      const next = { ...job, attempts: job.attempts + 1, error };
      delete next._active;
      if (next.attempts >= MAX_ATTEMPTS) {
        writeFileSync(join(failed, `${job.id}.json`), JSON.stringify(next));
      } else {
        const file = `${Date.now()}-${String(_seq++).padStart(6, '0')}_${job.id}.json`;
        writeFileSync(join(pending, file), JSON.stringify(next));
      }
      try {
        unlinkSync(join(pending, job._active));
      } catch {
        // file aktif sudah hilang: abaikan
      }
    },
    done: (job) => {
      try {
        unlinkSync(join(pending, job._active));
      } catch {
        // sudah hilang: abaikan
      }
    },
    close: () => {},
  };
}
