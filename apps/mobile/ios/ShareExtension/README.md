# iOS Share Extension (belum ter-wire)

`ShareViewController.swift` disiapkan sebagai referensi. Menambah target extension
butuh Xcode/macOS: buat target *Share Extension* bernama `ShareExtension`, tambahkan
file ini, aktifkan App Group `group.dev.seougc.seoUgc` untuk Runner + extension, dan
set `NSExtensionActivationSupportsWebURLWithMaxCount = 1`.

Di sisi Flutter, baca `UserDefaults(suiteName: "group.dev.seougc.seoUgc")["sharedText"]`
saat app aktif (butuh plugin platform channel; Android sudah jalan lewat MethodChannel).
