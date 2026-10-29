import { isConvertibleUrl } from './validateUrl.js';

// shortcut: in-memory jobId, ganti ULID saat butuh ordering di DB.
const newJobId = () =>
  `job_${DateTimeSafe()}`;

function DateTimeSafe() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
}

function send(res, status, body) {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (c) => {
      raw += c;
      if (raw.length > 8192) reject(new Error('payload_too_large'));
    });
    req.on('end', () => {
      try {
        resolve(raw ? JSON.parse(raw) : {});
      } catch {
        reject(new Error('invalid_json'));
      }
    });
  });
}

// enqueue: async ({url}) => {id}. Diinject agar route ter-test tanpa Redis.
export function makeApp(enqueue) {
  return async (req, res) => {
    if (req.method !== 'POST' || req.url !== '/v1/convert') {
      return send(res, 404, { error: 'not_found' });
    }
    let body;
    try {
      body = await readJson(req);
    } catch (e) {
      return send(res, 400, { error: e.message });
    }
    const url = typeof body.url === 'string' ? body.url.trim() : '';
    if (!isConvertibleUrl(url)) {
      return send(res, 400, { error: 'invalid_url' });
    }
    try {
      const job = await enqueue({ url });
      return send(res, 202, { jobId: job?.id ?? newJobId() });
    } catch {
      return send(res, 503, { error: 'queue_unavailable' });
    }
  };
}
