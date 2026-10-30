# Mobile (Flutter) — Share Receiver

Native Share Target: dari TikTok/IG → **Share** → **SEO UGC** → `POST /v1/convert`.

## Struktur

| Path | Isi |
|---|---|
| `android/.../MainActivity.kt` | Terima `ACTION_SEND` (`text/plain`), kirim teks ke Dart via MethodChannel `dev.seougc/share` |
| `android/.../AndroidManifest.xml` | `intent-filter` `ACTION_SEND` + `launchMode="singleTask"` (share saat app sudah terbuka) |
| `lib/main.dart` | Terima teks → `extractSharedUrl` → POST `/v1/convert` → tampilkan `jobId` |
| `lib/share_handler.dart` | Fungsi murni: ekstrak URL + bentuk payload |
| `ios/ShareExtension/` | Sumber extension (belum ter-wire, butuh Xcode/macOS) |

## Jalankan

```bash
export PATH="$HOME/flutter/bin:$PATH"
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE=http://10.0.2.2:4301   # emulator → host
```

`10.0.2.2` adalah localhost mesin host dari Android emulator. Untuk device fisik
pakai IP LAN, mis. `--dart-define=API_BASE=http://192.168.1.10:4301`.

## Verifikasi

```bash
flutter analyze     # 0 issue
flutter test        # 5 test (extractSharedUrl + payload)
flutter build apk --debug
```

Uji manual: buka TikTok → Share → pilih **SEO UGC** → app menampilkan
`Job dibuat: <jobId>`. Cek `GET /v1/articles/<jobId>` setelah worker selesai.

## Catatan

- iOS: target Share Extension harus dibuat manual di Xcode (App Group
  `group.dev.seougc.seoUgc`), lihat `ios/ShareExtension/README.md`.
- Backend harus hidup dan `API_BASE` reachable dari device.
