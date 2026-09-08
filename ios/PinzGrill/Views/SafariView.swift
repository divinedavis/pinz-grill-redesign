import SwiftUI
import SafariServices

/// SFSafariViewController: shares Safari's cookies and Keychain autofill, so
/// a diner who has a ChowNow account or saved card is already signed in.
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    var onDone: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.delegate = context.coordinator
        vc.preferredControlTintColor = UIColor(named: "AccentColor")
        vc.preferredBarTintColor = UIColor(named: "Brand")
        vc.dismissButtonStyle = .done
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) { onDone() }
    }
}
