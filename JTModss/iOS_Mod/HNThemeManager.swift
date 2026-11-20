import UIKit

enum HNThemeMode: String, CaseIterable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system: return "Theo hệ thống"
        case .light: return "Sáng"
        case .dark: return "Tối"
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum HNThemeManager {
    private static let modeKey = "hnmod_theme_mode"
    private static var observers: [NSObjectProtocol] = []

    static var mode: HNThemeMode {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: modeKey),
                  let mode = HNThemeMode(rawValue: rawValue) else {
                return .system
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modeKey)
            apply()
        }
    }

    static func install() {
        DispatchQueue.main.async {
            apply()
            guard observers.isEmpty else { return }

            let center = NotificationCenter.default
            observers.append(
                center.addObserver(
                    forName: UIWindow.didBecomeVisibleNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    apply()
                }
            )
            observers.append(
                center.addObserver(
                    forName: UIApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    apply()
                }
            )
        }
    }

    private static func apply() {
        let style = mode.interfaceStyle
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        for window in windows where window.overrideUserInterfaceStyle != style {
            window.overrideUserInterfaceStyle = style
        }
    }
}
