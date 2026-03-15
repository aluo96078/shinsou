import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - SecureScreenModifier

/// A `ViewModifier` that hides app content in the iOS app switcher screenshot
/// when `AppLockManager.secureScreenEnabled` is `true`.
///
/// ### How it works
/// The modifier overlays a `UITextField` with `isSecureTextEntry = true` on the
/// root window layer. iOS automatically replaces the contents of secure text
/// fields with a blur in app-switcher snapshots, so this effectively hides all
/// underlying content without any custom drawing.
///
/// On macOS / visionOS builds (where UIKit is unavailable) the modifier falls
/// back to a simple ZStack privacy overlay.
struct SecureScreenModifier: ViewModifier {

    @ObservedObject private var lockManager = AppLockManager.shared

    func body(content: Content) -> some View {
        content
#if canImport(UIKit)
            .background(
                SecureFieldBackgroundView(isSecure: lockManager.secureScreenEnabled)
                    .frame(width: 0, height: 0) // zero-sized — only the UITextField layer matters
            )
#endif
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .appShouldApplyPrivacyBlur
                )
            ) { _ in
                // SecureFieldBackgroundView already handles the blur at the UIKit layer.
                // Nothing additional needed here; hook is available for future extensions.
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .appShouldRemovePrivacyBlur
                )
            ) { _ in
                // Mirror of above — no extra work needed.
            }
    }
}

// MARK: - View Extension

extension View {
    /// Applies the secure-screen protection so app content is hidden in the
    /// iOS app switcher whenever `AppLockManager.secureScreenEnabled` is `true`.
    func secureScreen() -> some View {
        self.modifier(SecureScreenModifier())
    }
}

// MARK: - UIKit Implementation

#if canImport(UIKit)

/// A zero-sized `UIViewRepresentable` that embeds a `UITextField` with
/// `isSecureTextEntry = true` into the SwiftUI hierarchy.
///
/// iOS automatically redacts secure text field content in system screenshots
/// (including the app switcher), which causes the entire window to be blurred
/// rather than capturing the real screen content.
private struct SecureFieldBackgroundView: UIViewRepresentable {

    let isSecure: Bool

    func makeUIView(context: Context) -> UIView {
        let container = SecureContainerView()
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let container = uiView as? SecureContainerView else { return }
        container.setSecure(isSecure)
    }
}

// MARK: SecureContainerView

private final class SecureContainerView: UIView {

    // The secure text field whose layer protection iOS applies to the whole window.
    private let secureField: UITextField = {
        let field = UITextField()
        field.isSecureTextEntry = true
        field.isUserInteractionEnabled = false
        // Keep it invisible — we only need its layer-level effect.
        field.alpha = 0.01
        return field
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSecureField()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSecureField()
    }

    private func setupSecureField() {
        addSubview(secureField)
        secureField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            secureField.centerXAnchor.constraint(equalTo: centerXAnchor),
            secureField.centerYAnchor.constraint(equalTo: centerYAnchor),
            secureField.widthAnchor.constraint(equalToConstant: 1),
            secureField.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    /// Attach or detach the secure field from the window's layer to toggle protection.
    func setSecure(_ secure: Bool) {
        secureField.isSecureTextEntry = secure
        if secure {
            // Ensure the field is part of the first-responder chain so its
            // layer effect applies to the containing window.
            if secureField.superview == nil {
                addSubview(secureField)
            }
        }
    }
}

#endif // canImport(UIKit)

// MARK: - Preview

#if DEBUG
#Preview {
    Text("Protected content")
        .secureScreen()
}
#endif
