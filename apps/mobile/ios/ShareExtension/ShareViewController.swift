// iOS Share Extension: terima URL dari Share Sheet, simpan ke App Group,
// lalu Flutter (main.dart) membacanya dan POST ke /v1/convert.
//
// Belum ter-wire ke Runner.xcodeproj (butuh Xcode/macOS):
// 1. New Target → Share Extension, nama "ShareExtension"
// 2. Aktifkan App Group yang sama untuk Runner + ShareExtension
// 3. Tambahkan NSExtensionActivationRule → NSExtensionActivationSupportsWebURLWithMaxCount = 1
import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    private let appGroup = "group.dev.seougc.seoUgc"
    private let key = "sharedText"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = item.attachments, !providers.isEmpty else {
            finish()
            return
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, _ in
                let text = (item as? URL)?.absoluteString ?? (item as? String)
                self?.save(text)
            }
            return
        }
        finish()
    }

    private func save(_ text: String?) {
        if let text, let defaults = UserDefaults(suiteName: appGroup) {
            defaults.set(text, forKey: key)
        }
        finish()
    }

    private func finish() {
        DispatchQueue.main.async { self.extensionContext?.completeRequest(returningItems: nil) }
    }
}
