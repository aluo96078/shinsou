import SwiftUI

// MARK: - AboutScreen

struct AboutScreen: View {

    private let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }()

    private let buildNumber: String = {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }()

    @State private var showLicenses = false

    var body: some View {
        List {
            // MARK: App Header
            Section {
                HStack(spacing: 16) {
                    appIconView
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Shinsou")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            // MARK: Links
            Section("Connect") {
                LinkRow(
                    icon: "safari",
                    iconColor: .blue,
                    title: "Website",
                    url: "https://mihon.app"
                )
                LinkRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    iconColor: .black,
                    title: "GitHub",
                    subtitle: "View source code",
                    url: "https://github.com/mihonapp/mihon"
                )
                LinkRow(
                    icon: "bubble.left.and.bubble.right",
                    iconColor: Color(red: 0.35, green: 0.41, blue: 0.91),
                    title: "Discord",
                    subtitle: "Join the community",
                    url: "https://discord.gg/mihon"
                )
            }

            // MARK: Support
            Section("Help") {
                LinkRow(
                    icon: "doc.text",
                    iconColor: .orange,
                    title: "Documentation",
                    url: "https://mihon.app/docs"
                )
                LinkRow(
                    icon: "exclamationmark.bubble",
                    iconColor: .red,
                    title: "Report an Issue",
                    url: "https://github.com/mihonapp/mihon/issues/new"
                )
            }

            // MARK: Legal
            Section("Legal") {
                Button {
                    showLicenses = true
                } label: {
                    Label("Open Source Licenses", systemImage: "doc.plaintext")
                        .foregroundStyle(.primary)
                }

                LinkRow(
                    icon: "hand.raised",
                    iconColor: .teal,
                    title: "Privacy Policy",
                    url: "https://mihon.app/privacy"
                )
            }

            // MARK: Build info footer
            Section {
                EmptyView()
            } footer: {
                VStack(alignment: .center, spacing: 4) {
                    Text("Made with ❤️ by the Shinsou community")
                    Text("Version \(appVersion) (build \(buildNumber))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLicenses) {
            LicensesSheet()
        }
    }

    // MARK: - App Icon

    @ViewBuilder
    private var appIconView: some View {
        if let icon = appIconImage {
            Image(uiImage: icon)
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentColor)
                    .frame(width: 64, height: 64)
                Image(systemName: "book.closed.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }
        }
    }

    private var appIconImage: UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
            let last = iconFiles.last
        else { return nil }
        return UIImage(named: last)
    }
}

// MARK: - LinkRow

private struct LinkRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    let url: String

    var body: some View {
        Button {
            guard let u = URL(string: url) else { return }
            UIApplication.shared.open(u)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    if let sub = subtitle {
                        Text(sub)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - LicensesSheet

private struct LicensesSheet: View {
    @Environment(\.dismiss) private var dismiss

    struct License: Identifiable {
        let id = UUID()
        let name: String
        let license: String
        let url: String
    }

    private let licenses: [License] = [
        License(name: "GRDB.swift", license: "MIT", url: "https://github.com/groue/GRDB.swift"),
        License(name: "Nuke", license: "MIT", url: "https://github.com/kean/Nuke"),
        License(name: "NukeUI", license: "MIT", url: "https://github.com/kean/Nuke"),
        License(name: "JavaScriptCore", license: "LGPL / Apple", url: "https://developer.apple.com/documentation/javascriptcore"),
        License(name: "Swift Collections", license: "Apache 2.0", url: "https://github.com/apple/swift-collections"),
        License(name: "Swift Algorithms", license: "Apache 2.0", url: "https://github.com/apple/swift-algorithms"),
    ]

    var body: some View {
        NavigationStack {
            List(licenses) { lic in
                Button {
                    guard let url = URL(string: lic.url) else { return }
                    UIApplication.shared.open(url)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lic.name)
                                .foregroundStyle(.primary)
                            Text(lic.license)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Open Source Licenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AboutScreen()
    }
}
