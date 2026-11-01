import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readdirSync, readFileSync, utimesSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { MAX_ATTEMPTS, createFileQueue } from '../src/queue.js';

const fresh = () => createFileQueue(mkdtempSync(join(tmpdir(), 'q-')));

test('enqueue -> claim FIFO -> done menghapus file', () => {
  const q = fresh();
  const a = q.enqueue({ url: 'https://x/1' });
  const b = q.enqueue({ url: 'https://x/2' });
  assert.ok(a.id.startsWith('job_'));

  const c1 = q.claim();
  const c2 = q.claim();
  assert.equal(c1.url, 'https://x/1');
  assert.equal(c2.url, 'https://x/2');
  assert.equal(q.claim(), null);
  q.done(c1);
  q.done(c2);
  assert.deepEqual(readdirSync(join(q.dir, 'pending')), []);
  void b;
});

test('fail 3x -> failed, retry memperbarui attempts', () => {  const q = fresh();
  q.enqueue({ url: 'https://x/9' });
  for (let i = 0; i < MAX_ATTEMPTS; i++) {
    const c = q.claim();
    assert.ok(c);
    q.fail(c, 'boom');
  }
  assert.deepEqual(readdirSync(join(q.dir, 'pending')), []);
  const failed = readdirSync(join(q.dir, 'failed'));
  assert.equal(failed.length, 1);
  const body = JSON.parse(
    readFileSync(join(q.dir, 'failed', failed[0]), 'utf8'),
  );
  assert.equal(body.attempts, MAX_ATTEMPTS);
  assert.equal(body.error, 'boom');
});

test('releaseById mengembalikan file aktif', () => {
  const q = fresh();
  const { id } = q.enqueue({ url: 'https://x/7' });
  const c = q.claim();
  assert.equal(q.claim(), null);
  assert.equal(q.releaseById(id), true);
  assert.equal(q.releaseById('job_tidakada'), false);
  const c2 = q.claim();
  assert.equal(c2.url, 'https://x/7');
  q.done(c2);
  void c;
});

test('claim menuai file aktif basi', () => {
  const q = fresh();
  q.enqueue({ url: 'https://x/8' });
  const c = q.claim();
  // tuakan file aktif 31 menit
  const old = new Date(Date.now() - 31 * 60 * 1000);
  utimesSync(join(q.dir, 'pending', c._active), old, old);
  const c2 = q.claim();
  assert.equal(c2.url, 'https://x/8');
  q.done(c2);
});
