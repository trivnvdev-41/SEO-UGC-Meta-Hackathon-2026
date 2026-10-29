# Mobile Share Receiver

Native Share Target — terima link TikTok/IG via **Share → SEO UGC**.

## Alur

1. User Share dari TikTok/IG → `ShareReceiverActivity` terima `ACTION_SEND` (`text/plain`).
2. Ekstrak URL dari `Intent.EXTRA_TEXT`.
3. `POST /v1/convert` dengan body `{ "url": "<tiktok/ig link>" }`.

## Verifikasi

- Manifest valid XML + ada `intent-filter` `ACTION_SEND`.
- Unit logika ekstrak URL: `lib/share_handler.dart` (`extractSharedUrl`).
