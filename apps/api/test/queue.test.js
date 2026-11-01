import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readdirSync, readFileSync } from 'node:fs';
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

test('fail 3x -> failed, retry memperbarui attempts', () => {
  const q = fresh();
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
