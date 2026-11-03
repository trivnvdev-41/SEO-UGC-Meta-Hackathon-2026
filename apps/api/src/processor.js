import { existsSync, readdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { Worker } from 'bullmq';
import { MAX_ATTEMPTS, QUEUE_NAME } from './queue.js';
import { parseDraft } from './db.js';

/// Bentuk draft tersimpan (kolom Job.draft, JSON): semua yang dibutuhkan
/// Langkah 2 mobile tanpa memanggil worker lagi, kecuali user edit transkrip.
export function buildDraft(jobId, { url = '', creator = null, references = [] }, b) {
  return {
    transcript: b.transcript ?? '',
    confidence: b.confidence ?? null,
    frames: b.frame_options ?? [],
    selectedIndices: b.selected_image_indices ?? [],
    title: b.articles?.id?.title ?? '',
    creator: b.creator ?? creator,
    references,
    articles: b.articles ?? null,
    json_ld: b.json_ld ?? {},
    images: b.images ?? [],
  };
}

// Handler murni: worker HTTP -> DRAFT (bukan artikel) + status draft_ready.
// Artikel baru lahir saat publish (lihat publishDraft). Diinject agar ter-test.
// Bentuk job internal: { id, data: { url?, creator?, references? } }.
export function makeProcessor({ db, workerUrl, token, fetchImpl = fetch }) {
  return async (job) => {
    const url = job.data.url ?? '';
    const creator = job.data.creator ?? null;
    const references = job.data.references ?? [];
    await db.setJobStatus(job.id, 'processing', { url });

    const res = await fetchImpl(`${workerUrl}/process`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        job_id: job.id,
        ...(creator ? { creator } : {}),
      }),
    });
    if (!res.ok) throw new Error(`worker_${res.status}`);

    const b = await res.json();
    if (!b?.articles?.id || !b?.articles?.en) throw new Error('worker_bad_payload');

    await db.setJobStatus(job.id, 'draft_ready', {
      url,
      creator,
      draft: JSON.stringify(buildDraft(job.id, { url, creator, references }, b)),
    });
  };
}

/// Publish draft -> artikel. edited=true (transkrip diubah) memicu /regenerate;
/// tanpa edit = finalisasi langsung tanpa biaya LLM. Terakhir: status done +
/// hapus sumber video (satu-satunya tempat hapus yang aman).
export function makePublisher({ db, workerUrl, token, fetchImpl = fetch, mediaDir = '' }) {
  return async (jobId, pub = {}) => {
    const row = await db.getJob(jobId);
    if (!row) throw new Error('draft_missing');
    const draft = parseDraft(row.draft);
    if (!draft) throw new Error('draft_missing');
    const url = row.url ?? '';

    const title = typeof pub.title === 'string' && pub.title.trim()
      ? pub.title.trim().slice(0, 200)
      : null;
    let coverIndex = Number.isInteger(pub.coverIndex) && pub.coverIndex >= 0
      ? pub.coverIndex
      : null;
    const transcript = typeof pub.transcript === 'string' && pub.transcript.trim()
      ? pub.transcript.trim().slice(0, 20000)
      : draft.transcript;
    const references = Array.isArray(pub.references) ? pub.references : draft.references ?? [];
    const edited = pub.edited === true || transcript !== draft.transcript;

    const frames = Array.isArray(draft.frames) ? draft.frames : [];
    if (coverIndex === null || coverIndex >= frames.length) coverIndex = null;

    let articles = draft.articles;
    let jsonLd = draft.json_ld ?? {};
    let idFaqs = draft.articles?.id?.faqs ?? [];
    let enFaqs = draft.articles?.en?.faqs ?? [];
    // Indeks terpilih regen mengacu ke urutan `ordered` (cover dulu bila ada).
    let selected = null;
    if (edited) {
      const ordered = coverIndex !== null && frames[coverIndex]
        ? [frames[coverIndex], ...frames.filter((_, i) => i !== coverIndex)]
        : frames;
      const res = await fetchImpl(`${workerUrl}/regenerate`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          job_id: jobId,
          transcript,
          frame_urls: ordered.slice(0, 6),
          ...(draft.creator ? { creator: draft.creator } : {}),
        }),
      });
      if (!res.ok) throw new Error(`worker_${res.status}`);
      const b = await res.json();
      if (!b?.articles?.id || !b?.articles?.en) throw new Error('worker_bad_payload');
      articles = b.articles;
      jsonLd = b.json_ld ?? {};
      idFaqs = b.articles.id?.faqs ?? [];
      enFaqs = b.articles.en?.faqs ?? [];
      selected = Array.isArray(b.selected_image_indices)
        ? b.selected_image_indices.filter((i) => Number.isInteger(i))
        : [];
    }

    const coverUrl = coverIndex !== null ? frames[coverIndex] : null;
    let images;
    if (edited) {
      const ordered = coverIndex !== null && frames[coverIndex]
        ? [frames[coverIndex], ...frames.filter((_, i) => i !== coverIndex)]
        : frames;
      const picked = (selected ?? [])
        .map((i) => ordered[i])
        .filter((u) => typeof u === 'string' && u !== coverUrl);
      images = [
        ...(coverUrl ? [coverUrl] : []),
        ...picked,
        ...ordered.filter(
          (u) => u !== coverUrl && !picked.includes(u)),
      ].slice(0, 3);
    } else {
      images = [
        ...(coverUrl ? [coverUrl] : []),
        ...((draft.images ?? []).filter((u) => u !== coverUrl)),
      ].slice(0, 3);
    }

    await db.saveArticle({
      id: jobId,
      videoUrl: url,
      creator: draft.creator ?? null,
      images,
      id_body: title
        ? { ...articles.id, title }
        : articles.id,
      en_body: articles.en,
      json_ld: jsonLd,
      references,
      id_faqs: idFaqs,
      en_faqs: enFaqs,
    });
    await db.setJobStatus(jobId, 'done', { url, articleId: jobId });
    // Satu-satunya hapus sumber yang aman: artikel SUDAH tersimpan.
    // Media milik job draft asal (pub.origId); job publish tak punya media.
    const mediaOwner = pub.origId || jobId;
    if (mediaDir) {
      try {
        rmSync(join(mediaDir, mediaOwner), { recursive: true, force: true });
      } catch {
        /* sisa media: aman, bukan fatal */
      }
    }
    return { id: jobId };
  };
}

// Media dianggap siap bila video.mp4 ada, atau audio.mp3 + ≥1 frame.
function mediaPresent(mediaDir, jobId) {
  if (!mediaDir) return false;
  const dir = join(mediaDir, jobId);
  try {
    if (existsSync(join(dir, 'video.mp4'))) return true;
    if (!existsSync(join(dir, 'audio.mp3'))) return false;
    return readdirSync(dir).some((f) => /^frame_\d{3}\.jpg$/.test(f));
  } catch {
    return false;
  }
}

// Handler BullMQ: cek kesiapan media, lalu proses. Diekspor agar ter-test
// tanpa Redis; startWorker hanya memasang wiring BullMQ di atasnya.
export function createJobHandler({ db, workerUrl, token, fetchImpl, mediaDir = '' }) {
  const process = makeProcessor({ db, workerUrl, token, fetchImpl });
  const publish = makePublisher({ db, workerUrl, token, fetchImpl, mediaDir });
  return async (bullJob) => {
    const job = { id: bullJob.id, data: bullJob.data ?? {} };
    if (job.data.kind === 'publish') {
      await publish(job.id, job.data.publish ?? {});
      return;
    }
    if (!job.data.url && !mediaPresent(mediaDir, job.id)) {
      throw new Error('media_not_ready');
    }
    await process(job);
  };
}

// Worker BullMQ: event-driven (tanpa polling), concurrency via opts.
// Job upload (url kosong) yang medianya belum tersimpan dilempar agar
// dijadwal ulang via backoff, bukan diproses setengah jalan.
export function normalizeConcurrency(raw, fallback = 2) {
  const n = Number(raw);
  return Number.isInteger(n) && n >= 1 && n <= 32 ? n : fallback;
}
export function startWorker({
  queueName = QUEUE_NAME,
  redisUrl,
  connection,
  db,
  workerUrl,
  token,
  concurrency = 2,
  mediaDir = '',
  fetchImpl,
} = {}) {
  const handler = createJobHandler({ db, workerUrl, token, fetchImpl, mediaDir });
  const worker = new Worker(queueName, handler, {
    connection: connection ?? { url: redisUrl },
    concurrency,
    // Transkrip 60 detik + LLM bisa >60 dtk; lock default 30 dtk memicu
    // duplikat proses. 10 menit aman untuk video ≤180 dtk.
    lockDuration: 600000,
  });
  worker.on('failed', async (job, err) => {
    if (!job) return;
    console.error(`job ${job.id} attempt ${job.attemptsMade} failed: ${String(err?.message ?? err).slice(0, 200)}`);
    if (job.attemptsMade >= MAX_ATTEMPTS) {
      await db
        .setJobStatus(job.id, 'failed', {
          url: job.data?.url ?? '',
          error: String(err?.message ?? err).slice(0, 500),
        })
        .catch(() => {});
    }
  });
  return worker;
}
