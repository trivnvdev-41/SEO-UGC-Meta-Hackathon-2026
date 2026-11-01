import { randomUUID } from 'node:crypto';
import { mkdirSync, readdirSync, readFileSync, renameSync, statSync, unlinkSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// Antrean file FIFO untuk VPS mini (tanpa Redis): <dir>/pending/<id>.json.
// Gagal 3x -> <dir>/failed/<id>.json. Satu instance saja.
export const MAX_ATTEMPTS = 3;
// File .active_* lebih tua dari ini dianggap yatim (fetch-worker mati)
// dan dikembalikan ke pending saat claim berikutnya.
export const STALE_ACTIVE_MS = 30 * 60 * 1000;

let _seq = 0;

const activeName = (file) => `.active_${file}`;
const isActive = (f) => f.startsWith('.');
const unactive = (f) => f.replace(/^\.active_/, '');

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
    // Sambil jalan: kembalikan file .active_* basi (fetch-worker mati).
    claim: ({ staleMs = STALE_ACTIVE_MS, now = Date.now } = {}) => {
      for (const f of readdirSync(pending)) {
        if (!isActive(f) || !f.endsWith('.json')) continue;
        const path = join(pending, f);
        let mtime = 0;
        try {
          mtime = statSync(path).mtimeMs;
        } catch {
          continue;
        }
        if (now() - mtime > staleMs) {
          renameSync(path, join(pending, unactive(f)));
        }
      }
      const files = readdirSync(pending)
        .filter((f) => f.endsWith('.json') && !isActive(f))
        .sort();
      if (!files.length) return null;
      const path = join(pending, files[0]);
      const job = JSON.parse(readFileSync(path, 'utf8'));
      renameSync(path, join(pending, activeName(files[0])));
      return { ...job, _active: activeName(files[0]) };
    },
    release: (job) => {
      renameSync(
        join(pending, job._active),
        join(pending, unactive(job._active)),
      );
    },
    // Kembalikan file .active milik jobId (dipakai setelah media masuk).
    releaseById: (jobId) => {
      for (const f of readdirSync(pending)) {
        if (isActive(f) && f.includes(jobId)) {
          renameSync(join(pending, f), join(pending, unactive(f)));
          return true;
        }
      }
      return false;
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
