//
//  HNPresentHook.swift
//  UIViewController presentation hook
//

import UIKit

enum HNPresentHook {
    static func install() {
        UIViewController.swizzlePresent()
    }
}

private extension UIViewController {
    static var isPresentSwizzled: Bool {
        get { HNPresentHookState.isSwizzled }
        set { HNPresentHookState.isSwizzled = newValue }
    }

    @objc static func swizzlePresent() {
        guard !isPresentSwizzled else { return }
        isPresentSwizzled = true

        let cls = UIViewController.self
        let originalSelector = #selector(UIViewController.present(_:animated:completion:))
        let swizzledSelector = #selector(UIViewController.hn_presentHookPresent(_:animated:completion:))

        guard let originalMethod = class_getInstanceMethod(cls, originalSelector),
              let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector) else { return }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func hn_presentHookPresent(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        if String(describing: type(of: viewControllerToPresent)).contains("JTSheet") {
            let jtSheet = viewControllerToPresent
            HNJTSheetHook.injectSTKButton(into: jtSheet)
        }

        if let alert = viewControllerToPresent as? UIAlertController {
            let msg = (alert.message ?? "").lowercased()
            let title = (alert.title ?? "").lowercased()
            if (msg.contains("định vị") || msg.contains("location")) && (msg.contains("bật") || msg.contains("cài đặt") || title.contains("cảnh báo")) {
                DispatchQueue.main.async {
                    alert.dismiss(animated: false, completion: nil)
                }
                return
            }
            alert.injectCallActionsIfNeeded()
        } else if viewControllerToPresent.view != nil {
            DispatchQueue.main.async {
                self.inspectAndInterceptDialogs(in: viewControllerToPresent)
            }
        }

        self.hn_presentHookPresent(viewControllerToPresent, animated: flag, completion: completion)
    }

    func inspectAndInterceptDialogs(in viewController: UIViewController) {
        if let alert = viewController as? UIAlertController {
            alert.injectCallActionsIfNeeded()
            return
        }
        for child in viewController.children {
            inspectAndInterceptDialogs(in: child)
        }
    }
}

private enum HNPresentHookState {
    static var isSwizzled = false
}
