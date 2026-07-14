import SwiftUI

/// Thin wrapper around `UIActivityViewController` — SwiftUI's `ShareLink`
/// needs its item ready before the view builds, but the share card here has
/// to be rendered fresh at tap time (today's drawing keeps changing), so the
/// system share sheet is driven directly instead.
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
