# Mobile (Flutter) — Share Receiver

Native Share Target: TikTok/Instagram/YouTube → **Share** → **SEO UGC** → `POST /v1/convert`.

## Structure

| Path | Contents |
|---|---|
| `android/.../MainActivity.kt` | Receives `ACTION_SEND` (`text/plain`), forwards the text to Dart via MethodChannel `dev.seougc/share` |
| `android/.../AndroidManifest.xml` | `intent-filter` for `ACTION_SEND` + `launchMode="singleTask"` (works while the app is already open) |
| `lib/main.dart` | Receives text → validates → `POST /v1/convert` → shows `jobId` |
| `lib/share_handler.dart` | Pure functions: URL extraction, host allowlist, request payload |
| `ios/ShareExtension/` | Extension source (not wired, needs Xcode/macOS) |

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
flutter test        # 7 tests (extraction, host allowlist, payload)
flutter build apk --debug
```

Manual check: open TikTok → Share → pick **SEO UGC** → the app shows
`Job dibuat: <jobId>`. Then poll `GET /v1/articles/<jobId>` until the worker finishes.

## Notes

- iOS: the Share Extension target must be added manually in Xcode (App Group
  `group.dev.seougc.seoUgc`), see `ios/ShareExtension/README.md`.
- The backend must be running and `API_BASE` must be reachable from the device.
- Only `https` links to TikTok/Instagram/YouTube are sent; anything else is ignored
  in the UI before any request is made.
