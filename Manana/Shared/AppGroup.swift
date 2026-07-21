import Foundation

/// Resolves the App Group identifier actually granted to this process at
/// runtime, instead of trusting a hardcoded string.
///
/// AltStore (and other free-account sideloaders) rewrite identifiers when they
/// re-sign the app — the bundle id `com.wonji.manana` becomes
/// `com.wonji.manana.<TEAMID>`, and the app group is rewritten the same way.
/// Because the main app and the widget extension both get rewritten
/// consistently, reading the real granted group out of the embedded
/// provisioning profile keeps them pointed at the same shared container.
/// Hardcoding the original string made `UserDefaults(suiteName:)` and the
/// shared file container silently fail after sideloading, so the widget only
/// ever saw placeholders.
enum AppGroup {
    /// What the project declares in its entitlements — the value used when
    /// signed normally (Xcode, simulator, App Store), and the fallback /
    /// preferred match when several groups are present.
    static let declared = "group.com.wonji.manana"

    /// The group this process can actually use. Computed once at launch.
    static let identifier: String = resolve()

    private static func resolve() -> String {
        guard let groups = profileAppGroups(), !groups.isEmpty else {
            return declared
        }
        // Prefer the one derived from our own group (handles environments that
        // inject unrelated groups too); otherwise take the first granted one.
        return groups.first { $0.contains("com.wonji.manana") } ?? groups[0]
    }

    /// The `application-groups` entitlement from this bundle's embedded
    /// provisioning profile. The profile is a CMS-signed binary blob with an
    /// XML plist inside it — slice out the `<?xml …</plist>` span and parse
    /// that. Returns nil on the simulator / any build without an embedded
    /// profile, so the declared fallback is used there.
    private static func profileAppGroups() -> [String]? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8))?.lowerBound,
              let end = data.range(of: Data("</plist>".utf8))?.upperBound,
              start < end
        else { return nil }

        let plistData = data.subdata(in: start..<end)
        guard let profile = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
              let entitlements = profile["Entitlements"] as? [String: Any]
        else { return nil }

        return entitlements["com.apple.security.application-groups"] as? [String]
    }
}
