# Mobile (Flutter) — SABA Upload

Upload video dari galeri → `POST /v1/uploads` → artikel dimasak di server.

## Structure

| Path | Contents |
|---|---|
| `android/.../MainActivity.kt` | MethodChannel `dev.seougc/share`: `openUrl` (buka link artikel di browser) |
| `android/.../AndroidManifest.xml` | `launchMode="singleTask"` + izin INTERNET |
| `lib/main.dart` | Forum home (header, tabs, trending, kartu) + sheet upload → `POST /v1/uploads` → poll → detail |
| `lib/upload.dart` | Picker galeri + upload multipart + progress (tanpa dependency tambahan) |
| `lib/notify.dart` | Local notification when a job finishes while the app is in background (tap opens the article) |
| `lib/feed.dart` | Article model + brand filter (pure, tested) |
| `lib/vote.dart` | Chip Setuju + downvote lokal dengan pop, +1 float, ring |
| `lib/md.dart` | Mini Markdown renderer mirroring the web one |
| `lib/article_detail.dart` | Native article detail (photos, body, rating, video link) |

## Run

```bash
export PATH="$HOME/flutter/bin:$PATH"
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE=http://10.0.2.2:4301   # emulator → host
```

`10.0.2.2` is the host machine's localhost as seen from the Android emulator. On a
physical device use the LAN IP, e.g. `--dart-define=API_BASE=http://192.168.1.10:4301`.

## Verify

```bash
flutter analyze     # 0 issues
flutter test        # feed, md, profile, vote
flutter build apk --debug
```

Manual check: ketuk **+** → pilih video dari galeri → app menunjukkan
progress upload lalu `Artikel jadi: <jobId>`.

## Notes

- Android-only: no iOS target in this repo.
- The backend must be running and `API_BASE` must be reachable from the device.
- Upload-only: alur link/share (`POST /v1/convert`) sudah dicabut dari mobile.
