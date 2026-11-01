import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { handleMediaUpload, parseMultipart } from '../src/mediaIngress.js';

const BOUND = 'seougc-test-boundary';

function part(name, filename, ctype, data) {
  const head = filename
    ? `Content-Disposition: form-data; name="${name}"; filename="${filename}"\r\nContent-Type: ${ctype}\r\n`
    : `Content-Disposition: form-data; name="${name}"\r\n`;
  return Buffer.concat([
    Buffer.from(`--${BOUND}\r\n${head}\r\n`),
    Buffer.from(data),
    Buffer.from('\r\n'),
  ]);
}

function reqOf(body, token = 'T') {
  return {
    url: '/v1/media/job_1',
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': `multipart/form-data; boundary=${BOUND}`,
    },
  };
}

function fakeDb(job = { id: 'job_1', url: 'https://x/v' }) {
  const calls = [];
  return {
    calls,
    getJob: async (id) => (id === job?.id ? job : null),
    setJobStatus: async (id, status, extra = {}) => {
      calls.push([id, status, extra]);
    },
  };
}

const send = (res, status, body) => {
  res.status = status;
  res.body = body;
  return status === 200;
};

function bodyOf() {
  return Buffer.concat([
    part('creator', null, null, '@hebat'),
    part('file', 'audio.mp3', 'audio/mpeg', 'MP3DATA'),
    part('file', 'frame_001.jpg', 'image/jpeg', 'JPG1'),
    part('file', 'frame_002.jpg', 'image/jpeg', 'JPG2'),
    Buffer.from(`--${BOUND}--\r\n`),
  ]);
}

test('upload valid -> file tersimpan + media_ready + true', async () => {
  const db = fakeDb();
  const dir = mkdtempSync(join(tmpdir(), 'm-'));
  const res = {};
  const body = bodyOf();
  const req = {
    ...reqOf(body),
    on: (ev, fn) => {
      if (ev === 'data') setImmediate(() => fn(body));
      if (ev === 'end') setImmediate(fn);
      return req;
    },
    destroy: () => {},
  };
  const ok = await handleMediaUpload(req, res, send, db, dir, 'T');
  assert.equal(ok, true);
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.files, [
    'audio.mp3',
    'frame_001.jpg',
    'frame_002.jpg',
  ]);
  assert.ok(existsSync(join(dir, 'job_1', 'audio.mp3')));
  assert.deepEqual(db.calls, [
    ['job_1', 'media_ready', { url: 'https://x/v', creator: '@hebat' }],
  ]);
});

test('tanpa token -> 401 false', async () => {
  const db = fakeDb();
  const res = {};
  const ok = await handleMediaUpload(
    reqOf(Buffer.alloc(0), 'SALAH'), res, send, db, tmpdir(), 'T');
  assert.equal(ok, false);
  assert.equal(res.status, 401);
});

test('job tak dikenal -> 404', async () => {
  const db = fakeDb(null);
  const res = {};
  const req = reqOf(Buffer.alloc(0));
  req.on = () => req;
  req.destroy = () => {};
  const ok = await handleMediaUpload(req, res, send, db, tmpdir(), 'T');
  assert.equal(ok, false);
  assert.equal(res.status, 404);
});

test('parseMultipart menolak tanpa boundary', () => {
  assert.throws(
    () => parseMultipart({ headers: {} }, Buffer.alloc(0)),
    /missing_boundary/,
  );
});
